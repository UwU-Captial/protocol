// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IUwU.sol";
import "../interfaces/IUwUPolicy.sol";
import "../interfaces/IPancakeRouter.sol";

contract SP0 is Ownable {
    IUwUPolicy policy;

    uint256 targetRebasePercentage;

    constructor(IUwUPolicy policy_) public {
        policy = policy_;
    }

    function setTargetRebasePercentage(uint256 targetRebasePercentage_)
        external
        onlyOwner
    {
        targetRebasePercentage = targetRebasePercentage_;
    }

    function onBeforeRebase(
        uint256 index_,
        uint256 uwuTotalSupply_,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external {}

    function onAfterRebase(
        uint256 index_,
        uint256 uwuTotalSupply_,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external {
        require(
            msg.sender == address(policy),
            "Only uwu policy contract can call this"
        );
    }
}
