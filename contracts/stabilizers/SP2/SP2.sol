// SPDX-License-Identifier: MIT
/*

██████╗ ███████╗██████╗  █████╗ ███████╗███████╗
██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝
██║  ██║█████╗  ██████╔╝███████║███████╗█████╗  
██║  ██║██╔══╝  ██╔══██╗██╔══██║╚════██║██╔══╝  
██████╔╝███████╗██████╔╝██║  ██║███████║███████╗
╚═════╝ ╚══════╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝
                                               

* UwU: BurnPool.sol
* Description:
* Pool that issues coupons for uwu sent to it. Then rewards those coupons when positive rebases happen
* Coded by: punkUnknown
*/
pragma solidity >=0.6.6;

import "./CouponRewards.sol";
import "./DepositRewards.sol";
import "./Params.sol";

contract SP2 is Params, CouponRewards, DepositRewards {
    event LogStartNewDepositDistributionCycle(
        uint256 depositShareAdded_,
        uint256 rewardRate_,
        uint256 periodFinish_
    );

    event LogNeutralRebase(bool rewardDistributionDisabled_);
    event LogCouponsBought(
        address buyer_,
        uint256 amount_,
        uint256 couponIssued_
    );

    event LogEmergencyWithdrawa(uint256 withdrawAmount_);
    event LogRewardsAccrued(
        uint256 index,
        uint256 exchangeRate_,
        uint256 rewardsAccrued_,
        uint256 expansionPercentageScaled_,
        bytes16 value_
    );

    event LogNewCouponCycle(
        uint256 index_,
        uint256 rewardAmount_,
        uint256 uwuPerEpoch_,
        uint256 rewardBlockPeriod_,
        uint256 couponBuyBlockPeriod_,
        uint256 couponLockBlockPeriod_,
        uint256 oracleLastPrice_,
        uint256 oracleNextUpdate_,
        uint256 epochsToReward_
    );

    event LogOraclePriceAndPeriod(uint256 price_, uint256 period_);

    /**
     * @notice Function that shows the current circulating balance
     * @return Returns circulating balance
     */
    function circBalance() public view returns (uint256) {
        uint256 totalSupply = uwu.totalSupply();

        return
            totalSupply
                .sub(uwu.balanceOf(address(policy)))
                .sub(uwu.balanceOf(burnPool1))
                .sub(uwu.balanceOf(burnPool2));
    }

    /**
     * @notice Function that is called when the next rebase is negative. If the last rebase was not negative then a
     * new coupon cycle starts. If the last rebase was also negative when nothing happens.
     */
    function startNewCouponCycle(uint256 exchangeRate_) internal {
        if (lastRebase != Rebase.NEGATIVE) {
            lastRebase = Rebase.NEGATIVE;

            uint256 rewardAmount;

            // For the special case when the pool launches and the next rebase is negative. Meaning no rewards are accured from
            // positive expansion and hence no negaitve reward cycles have started. Then we use our reward as the inital reward
            // setting too bootstrap the pool.
            if (rewardsAccrued == 0 && cyclesLength == 0) {
                // Get reward in relation to circulating balance multiplied by share
                rewardAmount = circBalance().mul(initialRewardShare).div(
                    10**18
                );
            } else if (
                enableMinimumRewardAccruedCap &&
                rewardsAccrued < minimumRewardAccruedCap
            ) {
                rewardAmount = circBalance().mul(minimumRewardAccruedCap).div(
                    10**18
                );
            } else if (
                enableMaximumRewardAccruedCap &&
                rewardsAccrued > maximumRewardAccruedCap
            ) {
                rewardAmount = circBalance().mul(maximumRewardAccruedCap).div(
                    10**18
                );
            } else {
                rewardAmount = circBalance()
                    .mul(rewardsAccrued.sub(10**18))
                    .div(10**18);
            }

            // Scale reward amount in relation uwu total supply
            uint256 rewardShare =
                rewardAmount.mul(10**18).div(uwu.totalSupply());

            // Percentage amount to be claimed per epoch. Only set at the start of first reward epoch.
            // Its the result of reward expansion to give out div by number of epochs to give in
            uint256 uwuPerEpoch = rewardShare.div(epochs);

            couponCycles.push(
                CouponCycle(
                    rewardShare,
                    uwuPerEpoch,
                    couponRewardBlockPeriod,
                    epochs,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0
                )
            );

            depositCycles.push(
                DepositCycle(false, depositRewardBlockPeriod, 0, 0, 0, 0, 0, 0)
            );

            oracleCycles.push(
                OracleCycle(
                    false,
                    couponBuyBlockPeriod,
                    couponLockBlockPeriod,
                    exchangeRate_,
                    block.number.add(couponBuyBlockPeriod)
                )
            );

            emit LogNewCouponCycle(
                cyclesLength,
                rewardShare,
                uwuPerEpoch,
                couponRewardBlockPeriod,
                couponBuyBlockPeriod,
                couponLockBlockPeriod,
                exchangeRate_,
                block.number.add(couponLockBlockPeriod),
                epochs
            );

            cyclesLength = cyclesLength.add(1);
            positiveToNeutralRebaseRewardsDisabled = false;
            rewardsAccrued = 0;
        } else {
            OracleCycle storage instance = oracleCycles[cyclesLength.sub(1)];

            instance.oracleLastPrice = exchangeRate_;
            instance.oracleNextUpdate = block.number.add(
                instance.oracleBuyBlockPeriod
            );

            emit LogOraclePriceAndPeriod(
                instance.oracleLastPrice,
                instance.oracleNextUpdate
            );
        }
        // Update oracle data to current timestamp
        oracle.updateData();
    }

    /**
     * @notice Function that issues rewards when a positive rebase is about to happen.
     * @param index_ The index of the pool
     * @param exchangeRate_ The current exchange rate at rebase
     * @param curveValue Value of the log normal curve
     */
    function issueRewards(
        uint256 index_,
        uint256 exchangeRate_,
        bytes16 curveValue
    ) internal {
        CouponCycle storage instance = couponCycles[cyclesLength.sub(1)];

        instance.epochsRewarded = instance.epochsRewarded.add(1);

        // Scale reward percentage in relation curve value
        uint256 uwuShareToBeRewarded =
            curve.bytes16ToUnit256(curveValue, instance.uwuPerEpoch);

        // Claim multi sig reward in relation to scaled uwu reward
        uint256 multiSigRewardToClaimShare =
            uwuShareToBeRewarded.mul(multiSigRewardShare).div(10**18);

        // Convert reward to token amount
        uint256 uwuClaimAmount =
            uwu.totalSupply().mul(uwuShareToBeRewarded).div(10**18);

        // Convert multisig reward to token amount
        uint256 multiSigRewardToClaimAmount =
            uwu.totalSupply().mul(multiSigRewardToClaimShare).div(10**18);

        if (
            policy.stabilizerClaimFromFund(
                index_,
                uwuClaimAmount,
                multiSigRewardAddress,
                multiSigRewardToClaimAmount
            )
        ) {
            // Start new reward distribution cycle in relation to just uwu claim amount
            startNewCouponDistributionCycle(
                exchangeRate_,
                uwuShareToBeRewarded,
                curveValue
            );
        }
    }

    /**
     * @notice Function called by the reward contract to start new distribution cycles
     * @param index_ Index of stabilizer
     * @param supplyDelta_ Supply delta of the rebase to happen
     * @param rebaseLag_ Rebase lag applied to the supply delta
     * @param exchangeRate_ Exchange rate at which the rebase is happening
     */
    function triggerStabilizer(
        uint256 index_,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external {
        require(
            msg.sender == address(policy),
            "Only uwu policy contract can call this"
        );

        if (supplyDelta_ < 0) {
            startNewCouponCycle(exchangeRate_);
        } else if (supplyDelta_ == 0) {
            if (lastRebase == Rebase.POSITIVE) {
                positiveToNeutralRebaseRewardsDisabled = true;
            }
            lastRebase = Rebase.NEUTRAL;
            emit LogNeutralRebase(positiveToNeutralRebaseRewardsDisabled);
        } else {
            lastRebase = Rebase.POSITIVE;

            if (cyclesLength != 0) {
                DepositCycle storage instance =
                    depositCycles[cyclesLength.sub(1)];

                if (!instance.started) {
                    startNewDepositDistributionCycle();
                }
            }

            uint256 currentSupply = uwu.totalSupply();
            uint256 newSupply = uint256(supplyDelta_.abs()).add(currentSupply);

            if (newSupply > MAX_SUPPLY) {
                newSupply = MAX_SUPPLY;
            }

            // Get the percentage expansion that will happen from the rebase
            uint256 expansionPercentage =
                newSupply.mul(10**18).div(currentSupply).sub(10**18);

            uint256 targetRate = 1050000000000000000;
            //policy.priceTargetRate().add(policy.upperDeviationThreshold());

            // Get the difference between the current price and the target price (1.05$ Busd)
            uint256 offset = exchangeRate_.add(curveShifter).sub(targetRate);

            // Use the offset to get the current curve value
            bytes16 value =
                curve.getCurveValue(
                    offset,
                    mean,
                    oneDivDeviationSqrtTwoPi,
                    twoDeviationSquare
                );

            // Expansion percentage is scaled in relation to the value
            uint256 expansionPercentageScaled =
                curve.bytes16ToUnit256(value, expansionPercentage).add(10**18);

            // On our first positive rebase rewardsAccrued rebase will be the expansion percentage
            if (rewardsAccrued == 0) {
                rewardsAccrued = expansionPercentageScaled;
            } else {
                // Subsequest positive rebases will be compounded with previous rebases
                rewardsAccrued = rewardsAccrued
                    .mul(expansionPercentageScaled)
                    .div(10**18);
            }

            emit LogRewardsAccrued(
                cyclesLength,
                exchangeRate_,
                rewardsAccrued,
                expansionPercentageScaled,
                value
            );

            // Rewards will not be issued if
            // 1. We go from neutral to positive and back to neutral rebase
            // 2. If now reward cycle has happened
            // 3. If no coupons bought in the expansion cycle
            // 4. If not all epochs have been rewarded
            if (
                !positiveToNeutralRebaseRewardsDisabled &&
                cyclesLength != 0 &&
                couponCycles[cyclesLength.sub(1)].totalBalance != 0 &&
                couponCycles[cyclesLength.sub(1)].epochsRewarded < epochs
            ) {
                issueRewards(index_, exchangeRate_, value);
            }
        }
    }

    /**
     * @notice Function that checks the currect price of the coupon oracle. If oracle price period has finished
     * then another oracle update is called.
     */
    function checkPriceOrUpdate() internal {
        uint256 lowerPriceThreshold = 950000000000000000;
        //policy.priceTargetRate().sub(policy.lowerDeviationThreshold());

        OracleCycle storage instance = oracleCycles[cyclesLength.sub(1)];

        if (block.number > instance.oracleNextUpdate) {
            bool valid;

            (instance.oracleLastPrice, valid) = oracle.getData();
            require(valid, "Price is invalid");

            if (instance.oracleLastPrice < lowerPriceThreshold) {
                instance.oracleNextUpdate = block.number.add(
                    instance.oracleBuyBlockPeriod
                );
                instance.couponBuying = true;
            } else {
                instance.oracleNextUpdate = block.number.add(
                    instance.oracleLockBlockPeriod
                );
                instance.couponBuying = false;
            }

            emit LogOraclePriceAndPeriod(
                instance.oracleLastPrice,
                instance.oracleNextUpdate
            );
        }
    }

    /**
     * @notice Function that allows users to buy coupuns by send in uwu to the contract. When ever coupons are being bought
     * the current we check the TWAP price of the uwu pair. If the price is above the lower threshold price (0.95 busd)
     * then no coupons can be bought. If the price is below than coupons can be bought. The uwu sent are routed to the
     * reward contract.
     * @param uwuSent UwU amount sent
     */
    function buyCoupons(uint256 uwuSent) external returns (bool) {
        require(
            !address(msg.sender).isContract(),
            "Caller must not be a contract"
        );
        require(
            lastRebase == Rebase.NEGATIVE,
            "Can only buy coupons with last rebase was negative"
        );
        checkPriceOrUpdate();

        CouponCycle storage rewardInstance = couponCycles[cyclesLength.sub(1)];
        DepositCycle storage depositInstance =
            depositCycles[cyclesLength.sub(1)];
        OracleCycle storage oracleInstance = oracleCycles[cyclesLength.sub(1)];

        if (oracleInstance.couponBuying) {
            uint256 uwuDepositShare =
                uwuSent.mul(10**18).div(uwu.totalSupply());

            rewardInstance.userBalance[msg.sender] = rewardInstance.userBalance[
                msg.sender
            ]
                .add(uwuSent);

            rewardInstance.totalBalance = rewardInstance.totalBalance.add(
                uwuSent
            );

            depositInstance.userBalance[msg.sender] = depositInstance
                .userBalance[msg.sender]
                .add(uwuDepositShare);

            depositInstance.totalBalance = depositInstance.totalBalance.add(
                uwuDepositShare
            );

            emit LogCouponsBought(
                msg.sender,
                uwuSent,
                rewardInstance.totalBalance
            );
            uwu.transferFrom(msg.sender, address(policy), uwuSent);

            return true;
        }
        return false;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 withdrawAmount = uwu.balanceOf(address(this));
        uwu.transfer(address(policy), withdrawAmount);
        emit LogEmergencyWithdrawa(withdrawAmount);
    }
}
