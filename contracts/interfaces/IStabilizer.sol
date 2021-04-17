// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IStabilizer {
    function owner() external returns (address);

    function onBeforeRebase(
        uint256 index,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_,
        int256 rebasePercentage_
    ) external;

    function onAfterRebase(
        uint256 index,
        int256 rebasePercentage_
    ) external;
}
