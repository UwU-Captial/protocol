// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Seed is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address devWallet;
    IERC20 public UwU;
    IERC20 public BNB;
    uint256 priceAtLaunch;
    uint256 tokenExchangeRate;

    uint256 BNBDeposited;
    uint256 UwUDistributed;

    constructor(
        IERC20 UwU_,
        IERC20 BNB_,
        address devWallet_,
        uint256 priceAtLaunch_,
        uint256 tokenExchangeRate_
    ) public {
        devWallet = devWallet_;

        UwU = UwU_;
        BNB = BNB_;
        priceAtLaunch = priceAtLaunch_;
        tokenExchangeRate = tokenExchangeRate_;
    }

    function deposit(uint256 amount) external {
        uint256 UwUToRecieve = amount.mul(tokenExchangeRate);

        BNBDeposited = BNBDeposited.add((amount));
        UwUDistributed = UwUDistributed.add(UwUToRecieve);

        BNB.transferFrom(msg.sender, devWallet, amount);
        UwU.transfer(msg.sender, UwUToRecieve);
    }
}
