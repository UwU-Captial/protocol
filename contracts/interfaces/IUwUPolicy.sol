// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IUwUPolicy {
    function rebase() external;

    function upperDeviationThreshold() external view returns (uint256);

    function lowerDeviationThreshold() external view returns (uint256);

    function priceTargetRate() external view returns (uint256);

    function stabilizerClaimFromFund(
        uint256 index_,
        uint256 amount_,
        address feeClaimant_,
        uint256 feeAmount_
    ) external returns (bool);
}
