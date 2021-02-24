// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IUwUPolicy {
    function rebase() external;

    function stabilizerClaimFromFund(
        uint256 index_,
        uint256 amount_,
        address feeClaimant_,
        uint256 feeAmount_
    ) external returns (bool);
}
