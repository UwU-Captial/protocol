// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IUwU.sol";
import "../interfaces/IUwUPolicy.sol";

abstract contract Stabilizer is Ownable {
    IUwU public uwu;
    IUwUPolicy public policy;

    //Pancake Router
    IPancakeRouter02 constant PANCAKE_ROUTER =
        IPancakeRouter02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    //UwU -> BUSD exchange path
    address[] public swapPath;
    //Treasury address
    address public treasury;
    //Reward fee, times 1e3. ex: 30 for 3%
    uint256 public fee;

    function setFee(uint256 fee_) external onlyOwner {
        fee = fee_;
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
    }

    function setSwapPath(address[] calldata swapPath_) external onlyOwner {
        swapPath = swapPath_;
    }

    constructor(
        IUwU uwu_,
        IUwUPolicy policy_,
        address[] memory swapPath_,
        address treasury_,
        uint256 fee_
    ) public {
        uwu = uwu_;
        policy = policy_;
        swapPath = swapPath_;
        treasury = treasury_;
        fee = fee_;
    }

    function onBeforeRebase(
        uint256 index,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external virtual;

    function onAfterRebase(
        uint256 index,
        uint256 supplyBeforeRebase_,
        uint256 supplyAfterRebase_,
        uint256 exchangeRate_
    ) external virtual;

    function swapUwUForTokens(uint256 amount) internal {
        uwu.approve(address(PANCAKE_ROUTER), amount);
        PANCAKE_ROUTER.swapExactTokensForTokens(
            amount,
            0,
            swapPath,
            treasury,
            block.timestamp + 100
        );
    }
}
