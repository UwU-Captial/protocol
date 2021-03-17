// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

/*

██╗   ██╗██╗    ██╗██╗   ██╗
██║   ██║██║    ██║██║   ██║
██║   ██║██║ █╗ ██║██║   ██║
██║   ██║██║███╗██║██║   ██║
╚██████╔╝╚███╔███╔╝╚██████╔╝
 ╚═════╝  ╚══╝╚══╝  ╚═════╝ 
                            
* UwU: Seed.sol
* Description:
* Seed contract for crowd sale of UwU
* Coded by: punkUnknown
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUwU.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";

contract Seed is Ownable, Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUwU public UwU;
    IERC20 public BNB;
    IERC20 public BUSD;
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IUniswapV2Pair public bnbBusdPair;
    IUniswapV2Pair public pair;
    address public devWallet;
    address public policy;

    uint256 public lpBalance;
    uint256 public priceAtLaunch;
    uint256 public tokenExchangeRate;
    uint256 public BNBCap;
    uint256 public walletBNBCap;
    uint256 public totalUwUReward;

    uint256 public seedDuration;
    uint256 public seedEndsAt;
    bool public seedEnabled;

    uint256 public remainingUwUDistributionDuration;
    uint256 public remainingUwUDistributionEndsAt;
    bool public remainingUwUDistributionEnabled;

    uint256 public totalBNBDeposited;
    uint256 public totalUwUDistributed;

    address[] path;

    struct User {
        uint256 BNBBalance;
        uint256 UwUClaimRoundOne;
        uint256 UwUClaimRoundTwo;
        uint256 UwUClaimed;
        uint256 UwULockInLps;
        uint256 LpSent;
    }

    address[] public userAddresses;
    mapping(address => User) public Users;

    function initialize(
        IUwU UwU_,
        IERC20 BNB_,
        IERC20 BUSD_,
        IUniswapV2Factory factory_,
        IUniswapV2Router02 router_,
        IUniswapV2Pair bnbBusdPair_,
        address policy_,
        address devWallet_,
        uint256 BNBCap_,
        uint256 walletBNBCap_,
        uint256 priceAtLaunch_,
        uint256 tokenExchangeRate_,
        uint256 seedDuration_,
        uint256 remainingUwUDistributionDuration_
    ) external initializer {
        UwU = UwU_;
        BNB = BNB_;
        BUSD = BUSD_;

        bnbBusdPair = bnbBusdPair_;
        devWallet = devWallet_;
        factory = factory_;
        router = router_;
        policy = policy_;

        path.push(address(BNB));
        path.push(address(BUSD));

        seedDuration = seedDuration_;
        remainingUwUDistributionDuration = remainingUwUDistributionDuration_;

        totalUwUReward = UwU.balanceOf(address(this));
        priceAtLaunch = priceAtLaunch_;
        BNBCap = BNBCap_;
        walletBNBCap = walletBNBCap_;
        tokenExchangeRate = tokenExchangeRate_;
    }

    function startSeed() external onlyOwner {
        require(!seedEnabled);
        seedEnabled = true;
        seedEndsAt = block.timestamp.add(seedDuration);
    }

    function deposit(uint256 amount) external {
        require(amount != 0);
        require(
            seedEnabled && block.timestamp < seedEndsAt,
            "Deposit time finished"
        );
        require(totalBNBDeposited.add(amount) <= BNBCap);
        User storage instance = Users[msg.sender];

        if (instance.BNBBalance == 0) {
            userAddresses.push(msg.sender);
        }

        uint256 currentBNBBalance = instance.BNBBalance.add(amount);
        //require(currentBNBBalance <= walletBNBCap, "Deposit Over Cap");

        instance.BNBBalance = currentBNBBalance;
        totalBNBDeposited = totalBNBDeposited.add((amount));

        uint256 UwUToRecieve = amount.mul(tokenExchangeRate).div(1 ether);
        instance.UwUClaimRoundOne = instance.UwUClaimRoundOne.add(
            UwUToRecieve.mul(57).div(100)
        );
        instance.UwUClaimRoundTwo = instance.UwUClaimRoundTwo.add(
            UwUToRecieve.mul(23).div(100)
        );
        instance.UwULockInLps = instance.UwULockInLps.add(
            UwUToRecieve.mul(20).div(100)
        );

        BNB.transferFrom(msg.sender, address(this), amount);
    }

    function swapBnbAndCreatePancakePair() external onlyOwner {
        require(
            seedEnabled &&
                (totalBNBDeposited == BNBCap || block.timestamp >= seedEndsAt)
        );

        uint256 currentPrice;
        (uint256 res0, uint256 res1, ) = bnbBusdPair.getReserves();

        if (bnbBusdPair.token0() == address(BNB)) {
            currentPrice = res1.mul(10**18).div(res0);
        } else {
            currentPrice = res0.mul(10**18).div(res1);
        }

        uint256 bnbToSwap = BNB.balanceOf(address(this)).mul(20).div(100);
        uint256 bnbToSwapToBusd = bnbToSwap.mul(currentPrice).div(10**18);

        BNB.approve(address(router), totalBNBDeposited);
        router.swapTokensForExactTokens(
            bnbToSwapToBusd,
            totalBNBDeposited,
            path,
            address(this),
            block.timestamp.add(20 minutes)
        );

        uint256 uwuLiquidity = UwU.balanceOf(address(this)).mul(20).div(100);

        UwU.approve(address(router), uwuLiquidity);
        BUSD.approve(address(router), bnbToSwapToBusd);

        totalUwUDistributed = totalUwUDistributed.add(uwuLiquidity);

        uint256 amount1;
        uint256 amount2;

        (amount1, amount2, lpBalance) = router.addLiquidity(
            address(UwU),
            address(BUSD),
            uwuLiquidity,
            bnbToSwapToBusd,
            uwuLiquidity,
            bnbToSwapToBusd,
            address(this),
            block.timestamp.add(20 minutes)
        );

        pair = IUniswapV2Pair(factory.getPair(address(UwU), address(BUSD)));
    }

    function transferTokensAndLps(uint256 lowerIndex, uint256 higherIndex)
        external
        onlyOwner
    {
        require(address(pair) != address(0));
        require(higherIndex < userAddresses.length);

        for (
            uint256 index = lowerIndex;
            index <= higherIndex;
            index = index.add(1)
        ) {
            address userAddr = userAddresses[index];
            User storage instance = Users[userAddr];

            uint256 uwuToTransfer = instance.UwUClaimRoundOne;
            uint256 lpToTransfer =
                lpBalance.mul(instance.BNBBalance).div(totalBNBDeposited);

            instance.UwUClaimed = instance.UwUClaimed.add(uwuToTransfer);
            instance.LpSent = lpToTransfer;

            totalUwUDistributed = totalUwUDistributed.add(uwuToTransfer);
            UwU.transfer(userAddr, uwuToTransfer);
            pair.transfer(userAddr, lpToTransfer);
        }
    }

    function withdrawRemainingBnB() external onlyOwner {
        remainingUwUDistributionEnabled = true;
        remainingUwUDistributionEndsAt = block.timestamp.add(
            remainingUwUDistributionDuration
        );

        BNB.safeTransfer(devWallet, BNB.balanceOf(address(this)));
    }

    function transferRemainingUwU(uint256 lowerIndex, uint256 higherIndex)
        external
        onlyOwner
    {
        require(
            remainingUwUDistributionEnabled &&
                block.timestamp >= remainingUwUDistributionEndsAt
        );
        for (
            uint256 index = lowerIndex;
            index <= higherIndex;
            index = index.add(1)
        ) {
            address userAddr = userAddresses[index];
            User storage instance = Users[userAddr];

            uint256 uwuToTransfer = instance.UwUClaimRoundTwo;
            instance.UwUClaimed = instance.UwUClaimed.add(uwuToTransfer);

            totalUwUDistributed = totalUwUDistributed.add(uwuToTransfer);
            UwU.transfer(userAddr, uwuToTransfer);
        }
    }
}
