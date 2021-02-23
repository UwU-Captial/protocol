// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "./Params.sol";

contract DepositRewards is Params {
    event LogDepositRewardClaimed(
        address user_,
        uint256 cycleIndex_,
        uint256 rewardClaimed_
    );

    modifier updateDepositReward(address account, uint256 index) {
        CouponCycle storage instance = couponCycles[index];

        instance.rewardPerTokenStored = depositRewardPerToken(index);
        instance.lastUpdateBlock = lastDepositRewardApplicable(index);
        if (account != address(0)) {
            instance.rewards[account] = earnedDeposit(index, account);
            instance.userRewardPerTokenPaid[account] = instance
                .rewardPerTokenStored;
        }
        _;
    }

    function lastDepositRewardApplicable(uint256 index)
        internal
        view
        returns (uint256)
    {
        return Math.min(block.number, depositCycles[index].periodFinish);
    }

    function depositRewardPerToken(uint256 index)
        internal
        view
        returns (uint256)
    {
        DepositCycle memory instance = depositCycles[index];

        if (instance.totalBalance == 0) {
            return instance.rewardPerTokenStored;
        }

        return
            instance.rewardPerTokenStored.add(
                lastDepositRewardApplicable(index)
                    .sub(instance.lastUpdateBlock)
                    .mul(instance.rewardRate)
                    .mul(10**18)
                    .div(instance.totalBalance)
            );
    }

    function earnedDeposit(uint256 index, address account)
        public
        view
        checkArrayAndIndex(index)
        returns (uint256)
    {
        DepositCycle storage instance = depositCycles[index];

        return
            instance.userBalance[account]
                .mul(
                depositRewardPerToken(index).sub(
                    instance.userRewardPerTokenPaid[account]
                )
            )
                .div(10**18)
                .add(instance.rewards[account]);
    }

    function getDepositReward(uint256 index)
        public
        updateDepositReward(msg.sender, index)
    {
        require(
            lastRebase == Rebase.POSITIVE,
            "Can only claim rewards when last rebase was positive"
        );
        uint256 reward = earnedDeposit(index, msg.sender);

        if (reward > 0) {
            DepositCycle storage instance = depositCycles[index];

            instance.rewards[msg.sender] = 0;

            uint256 rewardToClaim = uwu.totalSupply().mul(reward).div(10**18);

            instance.rewardsDistributed = instance.rewardsDistributed.add(
                reward
            );

            totalDepositRewardsDistributed = totalDepositRewardsDistributed.add(
                reward
            );

            emit LogDepositRewardClaimed(msg.sender, index, rewardToClaim);
            uwu.safeTransfer(msg.sender, rewardToClaim);
        }
    }

    function startNewDepositDistributionCycle()
        internal
        updateDepositReward(address(0), cyclesLength.sub(1))
    {
        DepositCycle storage instance = depositCycles[cyclesLength.sub(1)];
        instance.rewardRate = instance.totalBalance.div(
            instance.rewardBlockPeriod
        );

        instance.lastUpdateBlock = block.number;
        instance.periodFinish = block.number.add(instance.rewardBlockPeriod);
    }
}
