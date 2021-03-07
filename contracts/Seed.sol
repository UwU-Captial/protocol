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

contract Seed is Ownable, Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUwU public UwU;
    IERC20 public BNB;
    IERC20 public BUSD;
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IUniswapV2Pair public pair;
    address public devWallet;

    uint256 public lpBalance;
    uint256 public priceAtLaunch;
    uint256 public tokenExchangeRate;
    uint256 public BNBCap;
    uint256 public walletBNBCap;
    uint256 public UwUDistribution;

    uint256 public seedDuration;
    uint256 public seedEndsAt;
    bool public seedEnabled;

    uint256 public remainingUwUDistributionDuration;
    uint256 public remainingUwUDistributionEndsAt;
    bool public remainingUwUDistributionEnabled;

    uint256 public BNBDeposited;
    uint256 public UwUDistributed;

    address[] path;

    struct User {
        uint256 BNBBalance;
        uint256 UwUBalance;
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

        devWallet = devWallet_;
        factory = factory_;
        router = router_;

        path.push(address(BNB));
        path.push(address(BUSD));

        seedDuration = seedDuration_;
        remainingUwUDistributionDuration = remainingUwUDistributionDuration_;

        UwUDistribution = UwU.balanceOf(address(this));
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
        require(BNBDeposited.add(amount) <= BNBCap);
        User storage instance = Users[msg.sender];

        if (instance.BNBBalance == 0) {
            userAddresses.push(msg.sender);
        }

        uint256 currentBNBBalance = instance.BNBBalance.add(amount);
        require(currentBNBBalance <= walletBNBCap, "Deposit Over Cap");

        instance.BNBBalance = currentBNBBalance;
        BNBDeposited = BNBDeposited.add((amount));

        uint256 UwUToRecieve = amount.mul(tokenExchangeRate).div(1 ether);
        instance.UwUBalance = instance.UwUBalance.add(UwUToRecieve);

        BNB.transferFrom(msg.sender, address(this), amount);
    }

    function swapBnbAndCreatePancakePair() external onlyOwner {
        require(
            seedEnabled &&
                (BNBDeposited == BNBCap || block.timestamp >= seedEndsAt)
        );

        BNB.approve(address(router), BNBDeposited);
        router.swapTokensForExactTokens(
            150000 ether,
            BNBDeposited,
            path,
            address(this),
            block.timestamp.add(20 minutes)
        );

        uint256 amount1;
        uint256 amount2;

        UwU.approve(address(router), 4000 ether);
        BUSD.approve(address(router), 150000 ether);

        (amount1, amount2, lpBalance) = router.addLiquidity(
            address(UwU),
            address(BUSD),
            4000 ether,
            150000 ether,
            4000 ether,
            150000 ether,
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

            uint256 uwuToTransfer = instance.UwUBalance.mul(57).div(100);
            uint256 lpToTransfer =
                lpBalance.mul(instance.BNBBalance).div(BNBDeposited);

            instance.UwUBalance = instance.UwUBalance.sub(uwuToTransfer);
            instance.LpSent = lpToTransfer;

            UwUDistributed = UwUDistributed.add(uwuToTransfer);
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

    function transferRemainingUwU() external onlyOwner {
        require(
            remainingUwUDistributionEnabled &&
                block.timestamp >= remainingUwUDistributionEndsAt
        );
        for (
            uint256 index = 0;
            index < userAddresses.length;
            index = index.add(1)
        ) {
            address userAddr = userAddresses[index];
            User storage instance = Users[userAddr];

            uint256 amountToTransfer = instance.UwUBalance;
            instance.UwUBalance = 0;

            UwUDistributed = UwUDistributed.add(amountToTransfer);
            UwU.transfer(userAddr, amountToTransfer);
        }
    }
}
