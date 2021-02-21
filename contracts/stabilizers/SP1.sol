// SPDX-License-Identifier: MIT
/*

██████╗ ███████╗██████╗  █████╗ ███████╗███████╗
██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝
██║  ██║█████╗  ██████╔╝███████║███████╗█████╗  
██║  ██║██╔══╝  ██╔══██╗██╔══██║╚════██║██╔══╝  
██████╔╝███████╗██████╔╝██║  ██║███████║███████╗
╚═════╝ ╚══════╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝
                                               

* Debase: ExpansionRewarder.sol
* Description:
* Pool that pool the issues rewards on expansions of debase supply
* Coded by: punkUnknown
*/

pragma solidity >=0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Debase.sol";
import "../DebasePolicy.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public y;

    function setStakeToken(address _y) internal {
        y = IERC20(_y);
    }

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        y.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        y.safeTransfer(msg.sender, amount);
    }
}

contract SP1 is Ownable, LPTokenWrapper, ReentrancyGuard {
    using Address for address;

    event LogEmergencyWithdraw(uint256 number);
    event LogSetRewardPercentage(uint256 rewardPercentage_);
    event LogSetBlockDuration(uint256 duration_);
    event LogSetPoolEnabled(bool poolEnabled_);
    event LogStartNewDistribtionCycle(
        uint256 amount_,
        uint256 currentRewardRate_,
        uint256 expansionRewardRate_,
        uint256 stabilityRewardRate_,
        uint256 cycleEnds_
    );

    event LogSetStabilityRewardRatePercentage(
        uint256 stabilityRewardRatePercentage_
    );
    event LogSetRewardRate(uint256 rewardRate_);
    event LogSetEnableUserLpLimit(bool enableUserLpLimit_);
    event LogSetEnablePoolLpLimit(bool enablePoolLpLimit_);
    event LogSetUserLpLimit(uint256 userLpLimit_);
    event LogSetPoolLpLimit(uint256 poolLpLimit_);

    event LogRewardAdded(uint256 reward);
    event LogStaked(address indexed user, uint256 amount);
    event LogWithdrawn(address indexed user, uint256 amount);
    event LogRewardPaid(address indexed user, uint256 reward);
    event LogSetMultiSigPercentage(uint256 multiSigReward_);
    event LogSetMultiSigAddress(address multiSigAddress_);

    Debase public debase;
    DebasePolicy public policy;
    uint256 public blockDuration;
    bool public poolEnabled;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;

    uint256 public rewardPerTokenStoredMax;
    uint256 public rewardShare;

    uint256 public rewardPercentage;
    uint256 public rewardDistributed;

    uint256 public expansionRewardRate;
    uint256 public stabilityRewardRate;
    uint256 public stabilityRewardRatePercentage;
    uint256 public cycleEnds;

    uint256 public multiSigRewardPercentage;
    uint256 public multiSigRewardAmount;
    address public multiSigRewardAddress;

    //Flag to enable amount of lp that can be staked by a account
    bool public enableUserLpLimit;
    //Amount of lp that can be staked by a account
    uint256 public userLpLimit;

    //Flag to enable total amount of lp that can be staked by all users
    bool public enablePoolLpLimit;
    //Total amount of lp total can be staked
    uint256 public poolLpLimit;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    modifier enabled() {
        require(poolEnabled, "Pool isn't enabled");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = lastBlockRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier updateRewardMax() {
        rewardPerTokenStoredMax = rewardPerTokenMax();
        _;
    }

    /**
     * @notice Function to set how much reward the stabilizer will request
     */
    function setRewardPercentage(uint256 rewardPercentage_) external onlyOwner {
        rewardPercentage = rewardPercentage_;
        emit LogSetRewardPercentage(rewardPercentage);
    }

    /**
     * @notice Function to set how much of the expansion reward rate should be added to neutral reward rate
     */
    function setStabilityRewardRatePercentage(
        uint256 stabilityRewardRatePercentage_
    ) external onlyOwner {
        stabilityRewardRatePercentage = stabilityRewardRatePercentage_;
        emit LogSetStabilityRewardRatePercentage(stabilityRewardRatePercentage);
    }

    /**
     * @notice Function to set multiSig reward percentage
     */
    function setMultiSigReward(uint256 multiSigRewardPercentage_)
        external
        onlyOwner
    {
        multiSigRewardPercentage = multiSigRewardPercentage_;
        emit LogSetMultiSigPercentage(multiSigRewardPercentage);
    }

    /**
     * @notice Function to set multisig address
     */
    function setMultiSigAddress(address multiSigRewardAddress_)
        external
        onlyOwner
    {
        multiSigRewardAddress = multiSigRewardAddress_;
        emit LogSetMultiSigAddress(multiSigRewardAddress);
    }

    /**
     * @notice Function to set reward drop period
     */
    function setblockDuration(uint256 blockDuration_) external onlyOwner {
        require(blockDuration >= 1);
        blockDuration = blockDuration_;
        emit LogSetBlockDuration(blockDuration);
    }

    /**
     * @notice Function enabled or disable pool staking,withdraw
     */
    function setPoolEnabled(bool poolEnabled_) external onlyOwner {
        poolEnabled = poolEnabled_;
        emit LogSetPoolEnabled(poolEnabled);
    }

    /**
     * @notice Function to enable user lp limit
     */
    function setEnableUserLpLimit(bool enableUserLpLimit_) external onlyOwner {
        enableUserLpLimit = enableUserLpLimit_;
        emit LogSetEnableUserLpLimit(enableUserLpLimit);
    }

    /**
     * @notice Function to set user lp limit
     */
    function setUserLpLimit(uint256 userLpLimit_) external onlyOwner {
        require(
            userLpLimit_ <= poolLpLimit,
            "User lp limit cant be more than pool limit"
        );
        userLpLimit = userLpLimit_;
        emit LogSetUserLpLimit(userLpLimit);
    }

    /**
     * @notice Function to enable pool lp limit
     */
    function setEnablePoolLpLimit(bool enablePoolLpLimit_) external onlyOwner {
        enablePoolLpLimit = enablePoolLpLimit_;
        emit LogSetEnablePoolLpLimit(enablePoolLpLimit);
    }

    /**
     * @notice Function to set pool lp limit
     */
    function setPoolLpLimit(uint256 poolLpLimit_) external onlyOwner {
        require(
            poolLpLimit_ >= userLpLimit,
            "Pool lp limit cant be less than user lp limit"
        );
        poolLpLimit = poolLpLimit_;
        emit LogSetPoolLpLimit(poolLpLimit);
    }

    constructor(
        address debase_,
        address pairToken_,
        address policy_,
        uint256 rewardPercentage_,
        uint256 blockDuration_,
        uint256 stabilityRewardRatePercentage_,
        uint256 multiSigRewardPercentage_,
        address multiSigRewardAddress_,
        bool enableUserLpLimit_,
        uint256 userLpLimit_,
        bool enablePoolLpLimit_,
        uint256 poolLpLimit_
    ) public {
        setStakeToken(pairToken_);
        debase = Debase(debase_);
        policy = DebasePolicy(policy_);

        blockDuration = blockDuration_;
        rewardPercentage = rewardPercentage_;

        stabilityRewardRatePercentage = stabilityRewardRatePercentage_;
        multiSigRewardPercentage = multiSigRewardPercentage_;
        multiSigRewardAddress = multiSigRewardAddress_;
        userLpLimit = userLpLimit_;
        enableUserLpLimit = enableUserLpLimit_;
        poolLpLimit = poolLpLimit_;
        enablePoolLpLimit = enablePoolLpLimit_;
    }

    function triggerStabilizer(
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external {
        require(
            msg.sender == address(policy),
            "Only debase policy contract can call this"
        );

        if (multiSigRewardAmount != 0) {
            debase.transfer(
                multiSigRewardAddress,
                debase.gonsToAmount(multiSigRewardAmount)
            );
            multiSigRewardAmount = 0;
        }

        if (block.number >= cycleEnds) {
            if (supplyDelta_ >= 0) {
                if (rewardShare != 0) {
                    uint256 balanceLost = rewardShare.sub(rewardPerTokenMax());
                    debase.transfer(
                        address(policy),
                        debase.gonsToAmount(balanceLost)
                    );
                    rewardShare = 0;
                }

                uint256 rewardAmount =
                    debase.totalSupply().mul(rewardPercentage).div(10**18);

                multiSigRewardAmount = rewardAmount
                    .mul(multiSigRewardPercentage)
                    .div(10**18);

                uint256 totalRewardAmount =
                    multiSigRewardAmount.add(rewardAmount);

                policy.claimFromFund(totalRewardAmount);
                startNewDistribtionCycle(supplyDelta_, rewardAmount);
            }
        } else {
            if (block.number > periodFinish && supplyDelta_ >= 0) {
                startRewards();
            }

            if (supplyDelta_ > 0 && rewardRate != expansionRewardRate) {
                changeRewardRate(expansionRewardRate);
            } else if (supplyDelta_ == 0 && rewardRate != stabilityRewardRate) {
                changeRewardRate(stabilityRewardRate);
            } else if (supplyDelta_ < 0 && block.number < periodFinish) {
                pauseRewards();
            }
        }
    }

    /**
     * @notice Function allows for emergency withdrawal of all reward tokens back into stabilizer fund
     */
    function emergencyWithdraw() external onlyOwner {
        debase.transfer(address(policy), debase.balanceOf(address(this)));
        emit LogEmergencyWithdraw(block.number);
    }

    function lastBlockRewardApplicable() internal view returns (uint256) {
        return Math.min(block.number, periodFinish);
    }

    function rewardPerTokenMax() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStoredMax;
        }
        return
            rewardPerTokenStoredMax.add(
                lastBlockRewardApplicable().sub(lastUpdateBlock).mul(rewardRate)
            );
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastBlockRewardApplicable()
                    .sub(lastUpdateBlock)
                    .mul(rewardRate)
                    .mul(10**18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(10**18)
                .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount)
        public
        override
        nonReentrant
        updateRewardMax()
        updateReward(msg.sender)
        enabled
    {
        require(
            !address(msg.sender).isContract(),
            "Caller must not be a contract"
        );
        require(amount > 0, "Cannot stake 0");

        if (enablePoolLpLimit) {
            uint256 lpBalance = totalSupply();
            require(
                amount.add(lpBalance) <= poolLpLimit,
                "Cant stake pool lp limit reached"
            );
        }
        if (enableUserLpLimit) {
            uint256 userLpBalance = balanceOf(msg.sender);
            require(
                userLpBalance.add(amount) <= userLpLimit,
                "Cant stake more than lp limit"
            );
        }

        super.stake(amount);
        emit LogStaked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        override
        nonReentrant
        updateRewardMax()
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        super.withdraw(amount);
        emit LogWithdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward()
        public
        nonReentrant
        updateRewardMax()
        updateReward(msg.sender)
        enabled
    {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;

            uint256 amountToClaim = debase.gonsToAmount(reward);
            debase.transfer(msg.sender, amountToClaim);

            emit LogRewardPaid(msg.sender, amountToClaim);
            rewardDistributed = rewardDistributed.add(reward);
        }
    }

    function startRewards() internal {
        lastUpdateBlock = block.number;
        periodFinish = cycleEnds;
    }

    function pauseRewards()
        internal
        updateRewardMax()
        updateReward(address(0))
    {
        periodFinish = block.number;
    }

    function changeRewardRate(uint256 rewardRate_)
        internal
        updateRewardMax()
        updateReward(address(0))
    {
        rewardRate = rewardRate_;
        emit LogSetRewardRate(rewardRate);
    }

    function startNewDistribtionCycle(int256 supplyDelta_, uint256 amount)
        internal
        updateReward(address(0))
    {
        // https://sips.synthetix.io/sips/sip-77
        require(
            amount < uint256(-1) / 10**18,
            "Rewards: rewards too large, would lock"
        );

        periodFinish = block.number.add(blockDuration);
        rewardPerTokenStoredMax = 0;
        cycleEnds = periodFinish;
        expansionRewardRate = amount.div(blockDuration);
        stabilityRewardRate = expansionRewardRate
            .mul(stabilityRewardRatePercentage)
            .div(10**18);

        if (supplyDelta_ > 0) {
            rewardRate = expansionRewardRate;
        } else {
            rewardRate = stabilityRewardRate;
        }

        lastUpdateBlock = block.number;

        emit LogStartNewDistribtionCycle(
            amount,
            rewardRate,
            expansionRewardRate,
            stabilityRewardRate,
            cycleEnds
        );
    }
}