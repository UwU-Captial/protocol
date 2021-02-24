// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IOracle {
    function getData() external returns (uint256, bool);

    function updateData() external;
}
