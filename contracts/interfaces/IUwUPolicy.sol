// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IUwUPolicy {
    function rebase() external;

    function stabilizerClaimFromFund(uint256 index, uint256 amount)
        external
        returns (bool);
}
