// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "./Stabilizer.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../lib/SafeMathInt.sol";

contract SP0 is Stabilizer {
    using SafeMath for uint256;

    uint256 targetRebasePercentage;

    constructor(
        IUwU uwu_,
        IUwUPolicy policy_,
        address[] memory swapPath_,
        address treasury_,
        uint256 fee_
    ) public Stabilizer(uwu_, policy_, swapPath_, treasury_, fee_) {}

    function setTargetRebasePercentage(uint256 targetRebasePercentage_)
        external
        onlyOwner
    {
        targetRebasePercentage = targetRebasePercentage_;
    }

    function onBeforeRebase(
        uint256 index_,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external override {}

    function onAfterRebase(
        uint256 index_,
        uint256 supplyBeforeRebase_,
        uint256 supplyAfterRebase_,
        uint256 exchangeRate_
    ) external override {
        require(
            msg.sender == address(policy),
            "Only uwu policy contract can call this"
        );

        uint256 rebasePercentage;

        if (supplyAfterRebase_ > supplyBeforeRebase_) {
            rebasePercentage = supplyAfterRebase_
                .mul(1 ether)
                .div(supplyBeforeRebase_)
                .sub(1 ether);

            if (rebasePercentage > targetRebasePercentage) {
                uint256 rebaseDifference =
                    rebasePercentage.sub(targetRebasePercentage);

                uint256 amount =
                    supplyAfterRebase_.mul(rebaseDifference).div(1 ether);

                policy.stabilizerClaimFromFund(index_, amount, address(0), 0);
            }
        }
    }
}
