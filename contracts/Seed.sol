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
import "hardhat/console.sol";

contract Seed is Ownable, Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

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

    uint256 constant maxPercentage = 1 ether;
    uint256 public seedDuration;
    uint256 public seedEndsAt;
    bool public seedEnabled;

    uint256 public remainingUwUDistributionDuration;
    uint256 public remainingUwUDistributionEndsAt;
    bool public remainingUwUDistributionEnabled;

    uint256 public totalBNBDeposited;
    uint256 public totalUwUDistributed;

    uint256 public uwuLiquidityPercentage;
    uint256 public uwuLockPercentage;
    uint256 public uwuUnlockPercentage;

    address[] path;

    struct User {
        uint256 BNBBalance;
        uint256 uwuClaim;
        uint256 uwuUnlocked;
        uint256 uwuLocked;
        uint256 UwULockInLps;
        uint256 LpSent;
        uint256 UwUClaimed;
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
        require(
            !address(msg.sender).isContract(),
            "Caller must not be a contract"
        );
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
        require(currentBNBBalance <= walletBNBCap, "Deposit Over Cap");

        instance.BNBBalance = currentBNBBalance;
        totalBNBDeposited = totalBNBDeposited.add((amount));

        instance.uwuClaim = instance.uwuClaim.add(
            amount.mul(tokenExchangeRate).div(10**18)
        );

        BNB.transferFrom(msg.sender, address(this), amount);
    }

    function swapBnbAndCreatePancakePair() external onlyOwner {
        require(
            seedEnabled &&
                (totalBNBDeposited == BNBCap || block.timestamp >= seedEndsAt),"Cant seed yet"
        );

        (uint256 res0, uint256 res1, ) = bnbBusdPair.getReserves();
        uint256 currentPrice = res1.mul(10**18).div(res0);

        console.log(currentPrice.div(10**18));

        uint256 bnbToSwap = BNB.balanceOf(address(this)).mul(1667).div(10000);
        uint256 bnbToSwapToBusd = bnbToSwap.mul(currentPrice).div(10**18);

        BNB.approve(address(router), totalBNBDeposited);
        router.swapTokensForExactTokens(
            bnbToSwapToBusd,
            totalBNBDeposited,
            path,
            address(this),
            block.timestamp.add(20 minutes)
        );

        uint256 uwuLiquidity =
            bnbToSwapToBusd.mul(10**18).div(3750000000000000000);
        uwuLiquidityPercentage = uwuLiquidity.mul(10**18).div(totalUwUReward);

        uint256 remainingPercentage = maxPercentage.sub(uwuLiquidityPercentage);
        uwuUnlockPercentage = remainingPercentage.mul(70).div(100);
        uwuLockPercentage = remainingPercentage.mul(30).div(100);

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

            uint256 lpToTransfer =
                lpBalance.mul(instance.BNBBalance).div(totalBNBDeposited);

            instance.uwuUnlocked = instance
                .uwuClaim
                .mul(uwuUnlockPercentage)
                .div(10**18);

            instance.uwuLocked = instance.uwuClaim.mul(uwuLockPercentage).div(
                10**18
            );

            instance.UwULockInLps = instance
                .uwuClaim
                .mul(uwuLiquidityPercentage)
                .div(10**18);

            instance.UwUClaimed = instance.UwUClaimed.add(instance.uwuUnlocked);
            instance.LpSent = lpToTransfer;

            totalUwUDistributed = totalUwUDistributed.add(instance.uwuUnlocked);

            UwU.transfer(userAddr, instance.uwuUnlocked);
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

            uint256 uwuToTransfer = instance.uwuLocked;
            instance.UwUClaimed = instance.UwUClaimed.add(uwuToTransfer);

            totalUwUDistributed = totalUwUDistributed.add(uwuToTransfer);
            UwU.transfer(userAddr, uwuToTransfer);
        }
    }
}
