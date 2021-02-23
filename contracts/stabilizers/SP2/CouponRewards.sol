// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "./Params.sol";

contract CouponRewards is Params {
    event LogCouponRewardClaimed(
        address user_,
        uint256 cycleIndex_,
        uint256 rewardClaimed_
    );

    event LogStartNewCouponDistributionCycle(
        uint256 exchangeRate_,
        uint256 poolShareAdded_,
        uint256 rewardRate_,
        uint256 periodFinish_,
        bytes16 curveValue_
    );
    modifier updateCouponReward(address account, uint256 index) {
        CouponCycle storage instance = couponCycles[index];

        instance.rewardPerTokenStored = couponRewardPerToken(index);
        instance.lastUpdateBlock = lastCouponRewardApplicable(index);
        if (account != address(0)) {
            instance.rewards[account] = earnedCoupon(index, account);
            instance.userRewardPerTokenPaid[account] = instance
                .rewardPerTokenStored;
        }
        _;
    }

    modifier checkArrayAndIndex(uint256 index) {
        require(cyclesLength != 0, "Cycle array is empty");
        require(
            index <= cyclesLength.sub(1),
            "Index should not me more than items in the cycle array"
        );
        _;
    }

    function lastCouponRewardApplicable(uint256 index)
        internal
        view
        returns (uint256)
    {
        return Math.min(block.number, couponCycles[index].periodFinish);
    }

    function couponRewardPerToken(uint256 index)
        internal
        view
        returns (uint256)
    {
        CouponCycle memory instance = couponCycles[index];

        if (instance.totalBalance == 0) {
            return instance.rewardPerTokenStored;
        }

        return
            instance.rewardPerTokenStored.add(
                lastCouponRewardApplicable(index)
                    .sub(instance.lastUpdateBlock)
                    .mul(instance.rewardRate)
                    .mul(10**18)
                    .div(instance.totalBalance)
            );
    }

    function earnedCoupon(uint256 index, address account)
        public
        view
        checkArrayAndIndex(index)
        returns (uint256)
    {
        CouponCycle storage instance = couponCycles[index];

        return
            instance.userBalance[account]
                .mul(
                couponRewardPerToken(index).sub(
                    instance.userRewardPerTokenPaid[account]
                )
            )
                .div(10**18)
                .add(instance.rewards[account]);
    }

    function getCouponReward(uint256 index)
        public
        updateCouponReward(msg.sender, index)
    {
        require(
            lastRebase == Rebase.POSITIVE,
            "Can only claim rewards when last rebase was positive"
        );
        uint256 reward = earnedCoupon(index, msg.sender);

        if (reward > 0) {
            CouponCycle storage instance = couponCycles[index];

            instance.rewards[msg.sender] = 0;

            uint256 rewardToClaim = uwu.totalSupply().mul(reward).div(10**18);

            instance.rewardsDistributed = instance.rewardsDistributed.add(
                reward
            );
            totalCouponRewardsDistributed = totalCouponRewardsDistributed.add(
                reward
            );

            emit LogCouponRewardClaimed(msg.sender, index, rewardToClaim);
            uwu.safeTransfer(msg.sender, rewardToClaim);
        }
    }

    function startNewCouponDistributionCycle(
        uint256 exchangeRate_,
        uint256 totalUwUToClaim,
        uint256 poolTotalShare,
        bytes16 curveValue
    ) internal updateCouponReward(address(0), cyclesLength.sub(1)) {
        // https://sips.synthetix.io/sips/sip-77
        require(
            uwu.balanceOf(address(this)).add(totalUwUToClaim) <
                uint256(-1) / 10**18,
            "Rewards: rewards too large, would lock"
        );
        CouponCycle storage instance = couponCycles[cyclesLength.sub(1)];

        if (block.number >= instance.periodFinish) {
            instance.rewardRate = poolTotalShare.div(
                instance.rewardBlockPeriod
            );
        } else {
            uint256 remaining = instance.periodFinish.sub(block.number);
            uint256 leftover = remaining.mul(instance.rewardRate);
            instance.rewardRate = poolTotalShare.add(leftover).div(
                instance.rewardBlockPeriod
            );
        }

        instance.lastUpdateBlock = block.number;
        instance.periodFinish = block.number.add(instance.rewardBlockPeriod);

        emit LogStartNewCouponDistributionCycle(
            exchangeRate_,
            poolTotalShare,
            instance.rewardRate,
            instance.periodFinish,
            curveValue
        );
    }
}
