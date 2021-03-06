// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

// Some code reproduced from
// https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2Pair.sol

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

contract ExampleOracleSimple {
    using FixedPoint for *;

    IUniswapV2Pair immutable pair;
    address public immutable token0;
    address public immutable token1;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    constructor(
        address factory,
        address tokenA,
        address tokenB
    ) public {
        IUniswapV2Pair _pair =
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
        pair = _pair;
        token0 = _pair.token0();
        token1 = _pair.token1();
        price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        // ensure that there's liquidity in the pair
        require(
            reserve0 != 0 && reserve1 != 0,
            "ExampleOracleSimple: NO_RESERVES"
        );
    }

    function currentAveragePrice() external view returns (uint256, uint256) {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));

        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        FixedPoint.uq112x112 memory token0avg =
            FixedPoint.uq112x112(
                uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
            );
        FixedPoint.uq112x112 memory token1avg =
            FixedPoint.uq112x112(
                uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
            );

        return (
            token0avg.mul(10**18).decode144(),
            token1avg.mul(10**18).decode144()
        );
    }

    function update() internal {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average = FixedPoint.uq112x112(
            uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
        );
        price1Average = FixedPoint.uq112x112(
            uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
        );

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, "ExampleOracleSimple: INVALID_TOKEN");
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }
}

contract CouponOracle is ExampleOracleSimple {
    address public uwu;
    address public pool;

    uint256 constant SCALE = 10**18;
    address public factory;

    constructor(
        address factory_,
        address uwu_,
        address busd_,
        address pool_
    ) public ExampleOracleSimple(factory_, uwu_, busd_) {
        factory = factory_;
        uwu = uwu_;
        pool = pool_;
    }

    function updateData() external {
        require(msg.sender == pool, "Only pool can update the oracle");
        update();
    }

    /**
     * @notice Get a price data sample from the oralce. Can only be called by the uwu policy.
     * @return The price and if the price if valid
     */
    function getData() external returns (uint256, bool) {
        require(msg.sender == pool, "Only pool can get the oracle price");
        update();
        uint256 price = consult(uwu, SCALE); // will return 1 BASED in Busd

        if (price == 0) {
            return (0, false);
        }

        return (price, true);
    }
}
