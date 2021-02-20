// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IPool {
    function rewardDistributed() external returns (uint256);

    function startPool() external;

    function periodFinish() external returns (uint256);
}
