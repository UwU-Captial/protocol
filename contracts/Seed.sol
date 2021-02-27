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

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./interfaces/IUwU.sol";

contract Seed is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUwU public UwU;
    IERC20 public BNB;
    IERC20 public BUSD;
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IUniswapV2Pair public pair;
    address public devWallet;

    uint256 lpBalance;
    uint256 priceAtLaunch;
    uint256 tokenExchangeRate;
    uint256 BNBCap;
    uint256 walletBNBCap;
    uint256 walletCap;
    uint256 UwUDistribution;
    uint256 seedEndsAt;
    uint256 remainingUwUDistribution;

    uint256 BNBDeposited;
    uint256 UwUDeposited;

    address[] path;

    struct User {
        uint256 BNBBalance;
        uint256 UwUBalance;
        uint256 LpSent;
    }

    address[] public userAddresses;
    mapping(address => User) Users;

    constructor(
        IUwU UwU_,
        IERC20 BNB_,
        IERC20 BUSD_,
        IUniswapV2Factory factory_,
        IUniswapV2Router02 router_,
        address devWallet_,
        uint256 BNBCap_,
        uint256 walletBNBCap_,
        uint256 priceAtLaunch_,
        uint256 tokenExchangeRate_,
        uint256 UwUDistribution_,
        uint256 seedDuration_,
        uint256 distributionTime_
    ) public {
        UwU = UwU_;
        BNB = BNB_;
        BUSD = BUSD_;

        devWallet = devWallet_;
        factory = factory_;
        router = router_;

        path.push(address(BNB));
        path.push(address(BUSD));

        UwUDistribution = UwUDistribution_;
        priceAtLaunch = priceAtLaunch_;
        seedEndsAt = block.timestamp.add(seedDuration_);
        remainingUwUDistribution = block.timestamp.add(distributionTime_);
        BNBCap = BNBCap_;
        walletBNBCap = walletBNBCap_;
        tokenExchangeRate = tokenExchangeRate_;
    }

    function deposit(uint256 amount) external {
        require(amount != 0);
        require(block.timestamp < seedEndsAt, "Deposit time finished");

        User storage instance = Users[msg.sender];

        if (instance.BNBBalance == 0) {
            userAddresses.push(msg.sender);
        }

        uint256 currentBNBBalance = instance.BNBBalance.add(amount);
        require(currentBNBBalance <= walletBNBCap, "Deposit Over Cap");

        instance.BNBBalance = currentBNBBalance;
        BNBDeposited = BNBDeposited.add((amount));

        uint256 UwUToRecieve = amount.mul(tokenExchangeRate);
        instance.UwUBalance = instance.UwUBalance.add(UwUToRecieve);
        UwUDeposited = UwUDeposited.add(UwUToRecieve);

        BNB.transferFrom(msg.sender, address(this), amount);
    }

    function swapBnbAndCreatePancakePair() external onlyOwner {
        require(block.timestamp >= seedEndsAt);

        router.swapETHForExactTokens(
            150000 ether,
            path,
            address(this),
            block.timestamp.add(20 minutes)
        );

        pair = IUniswapV2Pair(factory.createPair(address(UwU), address(BUSD)));

        uint256 amount1;
        uint256 amount2;

        (amount1, amount2, lpBalance) = router.addLiquidity(
            address(UwU),
            address(BUSD),
            40000 ether,
            150000 ether,
            40000 ether,
            150000 ether,
            address(this),
            block.timestamp.add(20 minutes)
        );

        transferTokensAndLps();
    }

    function transferTokensAndLps() internal {
        for (
            uint256 index = 0;
            index < userAddresses.length;
            index = index.add(1)
        ) {
            address userAddr = userAddresses[index];
            User storage instance = Users[userAddr];

            uint256 uwuToTransfer = instance.UwUBalance.mul(77).div(100);
            uint256 lpToTransfer =
                lpBalance.mul(instance.UwUBalance).div(UwUDeposited);

            instance.UwUBalance = instance.UwUBalance.sub(uwuToTransfer);
            instance.LpSent = lpToTransfer;

            UwU.transfer(userAddr, uwuToTransfer);
            pair.transfer(userAddr, lpToTransfer);
        }

        withdrawRemainingBnB();
    }

    function withdrawRemainingBnB() internal {
        BNB.safeTransfer(devWallet, BNB.balanceOf(address(this)));
    }

    function transferRemainingUwU() external onlyOwner {
        require(block.timestamp >= remainingUwUDistribution);
        for (
            uint256 index = 0;
            index < userAddresses.length;
            index = index.add(1)
        ) {
            address userAddr = userAddresses[index];
            User storage instance = Users[userAddr];

            uint256 amountToTransfer = instance.UwUBalance;
            instance.UwUBalance = 0;

            UwU.transfer(userAddr, amountToTransfer);
        }
    }
}
