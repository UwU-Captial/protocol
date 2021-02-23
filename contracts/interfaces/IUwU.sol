// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IUwU {
    function MAX_UINT256() external view returns (uint256);

    function INITIAL_FRAGMENTS_SUPPLY() external view returns (uint256);

    function TOTAL_GONS() external view returns (uint256);

    function MAX_SUPPLY() external view returns (uint256);

    function gonsPerFragment() external view returns (uint256);

    function gonsBalance(address who) external view returns (uint256);

    function allowedFragments(address from, address to)
        external
        view
        returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function gonsToAmount(uint256 amount) external view returns (uint256);

    function rebase(uint256 epoch, int256 supplyDelta)
        external
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}
