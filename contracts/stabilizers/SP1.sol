// SPDX-License-Identifier: MIT
/*

██╗   ██╗██╗    ██╗██╗   ██╗
██║   ██║██║    ██║██║   ██║
██║   ██║██║ █╗ ██║██║   ██║
██║   ██║██║███╗██║██║   ██║
╚██████╔╝╚███╔███╔╝╚██████╔╝
 ╚═════╝  ╚══╝╚══╝  ╚═════╝                                             

* UwU: ExpansionRewarder.sol
* Description:
* Pool that pool the issues rewards on expansions of uwu supply
* Coded by: punkUnknown, Ryuhei Matsuda
*/

pragma solidity >=0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/IUwU.sol";
import "../interfaces/IUwUPolicy.sol";
import "../interfaces/IPancakeRouter.sol";

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
        uint256 contractionRewardRate_,
        uint256 cycleEnds_
    );

    event LogSetContractionRewardRatePercentage(
        uint256 contractionRewardRatePercentage_
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
    event LogSetTreasuryAddress(address treasury_);
    event LogSetFeePercentage(uint256 fee_);

    IUwU public uwu;
    IUwUPolicy public policy;
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
    uint256 public contractionRewardRate;
    uint256 public contractionRewardRatePercentage;
    uint256 public cycleEnds;

    uint256 public multiSigRewardPercentage;
    address public multiSigRewardAddress;

    //Flag to enable amount of lp that can be staked by a account
    bool public enableUserLpLimit;
    //Amount of lp that can be staked by a account
    uint256 public userLpLimit;

    //Flag to enable total amount of lp that can be staked by all users
    bool public enablePoolLpLimit;
    //Total amount of lp total can be staked
    uint256 public poolLpLimit;

    //Pancake Router
    IPancakeRouter02 constant PANCAKE_ROUTER =
        IPancakeRouter02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    //UwU -> BUSD exchange path
    address[] public uwuBusdPath;
    //Treasury address
    address public treasury;
    //Reward fee, times 1e3. ex: 30 for 3%
    uint256 public fee;

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
    function setContractionRewardRatePercentage(
        uint256 contractionRewardRatePercentage_
    ) external onlyOwner {
        contractionRewardRatePercentage = contractionRewardRatePercentage_;
        emit LogSetContractionRewardRatePercentage(
            contractionRewardRatePercentage
        );
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

    /**
     * @notice Function to set treasury
     */
    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0), "Treasury cannot be 0x0");
        treasury = treasury_;
        emit LogSetTreasuryAddress(treasury);
    }

    /**
     * @notice Function to set fee
     */
    function setFee(uint256 fee_) external onlyOwner {
        fee = fee_;
        emit LogSetFeePercentage(fee);
    }

    function setUwUBusdPath(address[] memory uwuBusdPath_) public onlyOwner {
        uwuBusdPath = uwuBusdPath_;
    }

    constructor(
        address uwu_,
        address pairToken_,
        address policy_,
        uint256 rewardPercentage_,
        uint256 blockDuration_,
        uint256 contractionRewardRatePercentage_,
        uint256 multiSigRewardPercentage_,
        address multiSigRewardAddress_,
        bool enableUserLpLimit_,
        uint256 userLpLimit_,
        bool enablePoolLpLimit_,
        uint256 poolLpLimit_,
        address treasury_,
        uint256 fee_
    ) public {
        setStakeToken(pairToken_);
        uwu = IUwU(uwu_);
        policy = IUwUPolicy(policy_);

        blockDuration = blockDuration_;
        rewardPercentage = rewardPercentage_;

        contractionRewardRatePercentage = contractionRewardRatePercentage_;
        multiSigRewardAddress = multiSigRewardAddress_;
        multiSigRewardPercentage = multiSigRewardPercentage_;

        userLpLimit = userLpLimit_;
        enableUserLpLimit = enableUserLpLimit_;
        poolLpLimit = poolLpLimit_;
        enablePoolLpLimit = enablePoolLpLimit_;

        treasury = treasury_;
        fee = fee_;
    }

    function onBeforeRebase(
        uint256 index_,
        uint256 uwuTotalSupply_,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external {
        require(
            msg.sender == address(policy),
            "Only uwu policy contract can call this"
        );

        if (block.number >= cycleEnds) {
            if (supplyDelta_ >= 0) {
                if (rewardShare != 0) {
                    uint256 balanceLost = rewardShare.sub(rewardPerTokenMax());
                    uwu.transfer(
                        address(policy),
                        uwu.gonsToAmount(balanceLost)
                    );
                    rewardShare = 0;
                }

                uint256 poolRewardAmount =
                    uwu.totalSupply().mul(rewardPercentage).div(10**18);

                uint256 multiSigRewardAmount =
                    poolRewardAmount.mul(multiSigRewardPercentage).div(10**18);

                if (
                    policy.stabilizerClaimFromFund(
                        index_,
                        poolRewardAmount,
                        multiSigRewardAddress,
                        multiSigRewardAmount
                    )
                ) {
                    startNewDistribtionCycle(supplyDelta_, poolRewardAmount);
                }
            }
        } else {
            if (block.number > periodFinish && supplyDelta_ >= 0) {
                startRewards();
            }

            if (supplyDelta_ >= 0 && rewardRate != expansionRewardRate) {
                changeRewardRate(expansionRewardRate);
            } else if (
                supplyDelta_ < 0 && rewardRate != contractionRewardRate
            ) {
                changeRewardRate(contractionRewardRate);
            }
        }
    }

    function onAfterRebase(
        uint256 index_,
        uint256 uwuTotalSupply_,
        int256 supplyDelta_,
        int256 rebaseLag_,
        uint256 exchangeRate_
    ) external {}

    /**
     * @notice Function allows for emergency withdrawal of all reward tokens back into stabilizer fund
     */
    function emergencyWithdraw() external onlyOwner {
        uwu.transfer(address(policy), uwu.balanceOf(address(this)));
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

            uint256 amountToClaim = uwu.gonsToAmount(reward);

            if (fee > 0 && treasury != address(0)) {
                uint256 feeAmount = amountToClaim.mul(fee).div(1 ether);

                uwu.approve(address(PANCAKE_ROUTER), feeAmount);
                PANCAKE_ROUTER.swapExactTokensForTokens(
                    feeAmount,
                    0,
                    uwuBusdPath,
                    treasury,
                    block.timestamp
                );
                amountToClaim = amountToClaim.sub(feeAmount);
            }

            uwu.transfer(msg.sender, amountToClaim);

            emit LogRewardPaid(msg.sender, amountToClaim);
            rewardDistributed = rewardDistributed.add(reward);
        }
    }

    function startRewards() internal {
        lastUpdateBlock = block.number;
        periodFinish = cycleEnds;
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

        uint256 gonsAmount = uwu.amountToGons(amount);

        periodFinish = block.number.add(blockDuration);
        rewardPerTokenStoredMax = 0;
        cycleEnds = periodFinish;

        expansionRewardRate = gonsAmount.div(blockDuration);
        contractionRewardRate = expansionRewardRate
            .mul(contractionRewardRatePercentage)
            .div(10**18);

        if (supplyDelta_ >= 0) {
            rewardRate = expansionRewardRate;
        } else {
            rewardRate = contractionRewardRate;
        }

        lastUpdateBlock = block.number;

        emit LogStartNewDistribtionCycle(
            gonsAmount,
            rewardRate,
            expansionRewardRate,
            contractionRewardRate,
            cycleEnds
        );
    }
}
