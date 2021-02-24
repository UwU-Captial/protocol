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

contract Seed {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public UwU;
    IERC20 public BNB;

    uint256 priceAtLaunch;
    uint256 tokenExchangeRate;
    uint256 BNBCap;
    uint256 walletBNBCap;
    uint256 walletCap;
    uint256 UwUDistribution;

    uint256 BNBDeposited;
    uint256 UwUDistributed;

    mapping(address => uint256) BNBbalance;

    constructor(
        IERC20 UwU_,
        IERC20 BNB_,
        uint256 BNBCap_,
        uint256 walletBNBCap_,
        uint256 priceAtLaunch_,
        uint256 tokenExchangeRate_
    ) public {
        UwU = UwU_;
        BNB = BNB_;

        UwUDistribution = UwU.balanceOf(address(this));
        priceAtLaunch = priceAtLaunch_;
        BNBCap = BNBCap_;
        walletBNBCap = walletBNBCap_;
        tokenExchangeRate = tokenExchangeRate_;
    }

    function deposit(uint256 amount) external {
        uint256 currentBNBBalance = BNBbalance[msg.sender].add(amount);
        require(currentBNBBalance <= walletBNBCap);
        BNBbalance[msg.sender] = currentBNBBalance;
        BNBDeposited = BNBDeposited.add((amount));

        uint256 UwUToRecieve = amount.mul(tokenExchangeRate);
        UwUDistributed = UwUDistributed.add(UwUToRecieve);

        BNB.transferFrom(msg.sender, address(this), amount);
        UwU.transfer(msg.sender, UwUToRecieve);
    }
}
