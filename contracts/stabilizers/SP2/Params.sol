// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../lib/SafeMathInt.sol";
import '../../interfaces/IUwU.sol';

interface IUwUPolicy {
    function upperDeviationThreshold() external view returns (uint256);

    function lowerDeviationThreshold() external view returns (uint256);

    function priceTargetRate() external view returns (uint256);
}

    function getData() external returns (uint256, bool);

    function updateData() external;
}

contract Params is Ownable, Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using Address for address;

    event LogSetOracle(IOracle oracle_);
    event LogSetRewardBlockPeriod(uint256 rewardBlockPeriod_);
    event LogSetMultiSigRewardShare(uint256 multiSigRewardShare_);
    event LogSetInitialRewardShare(uint256 initialRewardShare_);
    event LogSetMultiSigRewardAddress(address multiSigRewardAddress_);
    event LogSetOracleBlockPeriod(uint256 oracleBlockPeriod_);
    event LogSetEpochs(uint256 epochs_);
    event LogSetCurveShifter(uint256 curveShifter_);
    event LogSetMeanAndDeviationWithFormulaConstants(
        bytes16 mean_,
        bytes16 deviation_,
        bytes16 peakScaler_,
        bytes16 oneDivDeviationSqrtTwoPi_,
        bytes16 twoDeviationSquare_
    );
    event LogSetMinimumRewardAccruedCap(uint256 minimumRewardAccruedCap_);
    event LogSetMaximumRewardAccruedCap(uint256 maximumRewardAccruedCap_);

    event LogSetEnableMinimumRewardAccruedCap(
        bool enableMinimumRewardAccruedCap_
    );
    event LogSetEnableMaximumRewardAccruedCap(
        bool enableMaximumRewardAccruedCap_
    );

    uint256 internal constant MAX_SUPPLY = ~uint128(0); // (2^128) - 1

    // Address of the uwu policy/reward contract
    IUwUPolicy public policy;
    // Address of the uwu token
    IUwU public uwu;
    // Address of the oracle contract managing opening and closing of coupon buying
    IOracle public oracle;
    // Address of the multiSig treasury
    address public multiSigRewardAddress;

    // Address of busd staking pool with burned tokens
    address public burnPool1;
    // Address of uwu/busd staking pool with burned tokens
    address public burnPool2;

    // Mean for log normal distribution
    bytes16 public mean;
    // Deviation for log normal distribution
    bytes16 public deviation;
    // Multiplied into log normal curve to raise or lower the peak. Initially set to 1 in bytes16
    bytes16 public peakScaler = 0x3fff565013f27f16fc74748b3f33c2db;
    // Result of 1/(Deviation*Sqrt(2*pi)) for optimized log normal calculation
    bytes16 public oneDivDeviationSqrtTwoPi;
    // Result of 2*(Deviation)^2 for optimized log normal calculation
    bytes16 public twoDeviationSquare;

    // The number rebases coupon rewards can be distributed for
    uint256 public epochs;

    // The total rewards in %s of the market cap distributed
    uint256 public totalCouponRewardsDistributed;
    uint256 public totalDepositRewardsDistributed;

    // The period within which coupons can be bought
    uint256 public couponBuyBlockPeriod;
    // The period witnin which coupons cant be bought
    uint256 public couponLockBlockPeriod;

    // Tracking supply expansion in relation to total supply.
    // To be given out as rewards after the next contraction
    uint256 public rewardsAccrued;
    // Offset to shift the log normal curve
    uint256 public curveShifter;
    // The  block duration over which rewards are given out
    uint256 public couponRewardBlockPeriod = 6400;
    uint256 public depositRewardBlockPeriod = 6400;

    // The percentage of the total supply to be given out on the first instance
    // when the pool launches and the next rebase is negative
    uint256 public initialRewardShare;
    //Flags to enable disable cap checks
    bool public enableMaximumRewardAccruedCap = true;
    bool public enableMinimumRewardAccruedCap = true;
    // Minimum reward to be given out on the condition that expansion is too low
    uint256 public minimumRewardAccruedCap = 50000000000000000;
    // Maximum reward to be given out on the condition that expansion is too high
    uint256 public maximumRewardAccruedCap = 100000000000000000;
    // The percentage of the current reward to be given in an epoch to be routed to the treasury
    uint256 public multiSigRewardShare;
    // Flag to stop rewards to be given out if rebases go from positive to neutral
    bool public positiveToNeutralRebaseRewardsDisabled;

    enum Rebase {POSITIVE, NEUTRAL, NEGATIVE, NONE}
    // Showing last rebase that happened
    Rebase public lastRebase;

    /**
     * @notice Function to set the oracle period after which the price updates
     * @param couponBuyBlockPeriod_ New oracle period
     */
    function setCouponBuyBlockPeriod(uint256 couponBuyBlockPeriod_)
        external
        onlyOwner
    {
        couponBuyBlockPeriod = couponBuyBlockPeriod_;
        emit LogSetOracleBlockPeriod(couponBuyBlockPeriod);
    }

    /**
     * @notice Function to set the oracle period after which the price updates
     * @param couponLockBlockPeriod_ New oracle period
     */
    function setCouponLockBlockPeriod(uint256 couponLockBlockPeriod_)
        external
        onlyOwner
    {
        couponLockBlockPeriod = couponLockBlockPeriod_;
        emit LogSetOracleBlockPeriod(couponLockBlockPeriod_);
    }

    /**
     * @notice Function to set the offest by which to shift the log normal curve
     * @param curveShifter_ New curve offset
     */
    function setCurveShifter(uint256 curveShifter_) external onlyOwner {
        curveShifter = curveShifter_;
        emit LogSetCurveShifter(curveShifter);
    }

    /**
     * @notice Function to set the number of epochs/rebase triggers over which to distribute rewards
     * @param epochs_ New rewards epoch
     */
    function setEpochs(uint256 epochs_) external onlyOwner {
        epochs = epochs_;
        emit LogSetEpochs(epochs);
    }

    /**
     * @notice Function to set the oracle address for the coupon buying and closing
     * @param oracle_ Address of the new oracle
     */
    function setOracle(IOracle oracle_) external onlyOwner {
        oracle = oracle_;
        emit LogSetOracle(oracle);
    }

    /**
     * @notice Function to set the initial reward if the pools first rebase is negative
     * @param initialRewardShare_ New initial reward share in %s
     */
    function setInitialRewardShare(uint256 initialRewardShare_)
        external
        onlyOwner
    {
        initialRewardShare = initialRewardShare_;
        emit LogSetInitialRewardShare(initialRewardShare);
    }

    /**
     * @notice Function to set the initial reward if the pools first rebase is negative
     * @param minimumRewardAccruedCap_ New initial reward share in %s
     */
    function setMinimumRewardAccruedCap(uint256 minimumRewardAccruedCap_)
        external
        onlyOwner
    {
        minimumRewardAccruedCap = minimumRewardAccruedCap_;
        emit LogSetMinimumRewardAccruedCap(minimumRewardAccruedCap);
    }

    /**
     * @notice Function to set the initial reward if the pools first rebase is negative
     * @param maximumRewardAccruedCap_ New initial reward share in %s
     */
    function setMaximumRewardAccruedCap(uint256 maximumRewardAccruedCap_)
        external
        onlyOwner
    {
        maximumRewardAccruedCap = maximumRewardAccruedCap_;
        emit LogSetMaximumRewardAccruedCap(maximumRewardAccruedCap);
    }

    /**
     * @notice Function to set the initial reward if the pools first rebase is negative
     * @param enableMinimumRewardAccruedCap_ New initial reward share in %s
     */
    function setEnableMinimumRewardAccruedCap(
        bool enableMinimumRewardAccruedCap_
    ) external onlyOwner {
        enableMinimumRewardAccruedCap = enableMinimumRewardAccruedCap_;
        emit LogSetEnableMinimumRewardAccruedCap(enableMinimumRewardAccruedCap);
    }

    /**
     * @notice Function to set the initial reward if the pools first rebase is negative
     * @param enableMaximumRewardAccruedCap_ New initial reward share in %s
     */
    function setEnableMaximumRewardAccruedCap(
        bool enableMaximumRewardAccruedCap_
    ) external onlyOwner {
        enableMaximumRewardAccruedCap = enableMaximumRewardAccruedCap_;
        emit LogSetEnableMaximumRewardAccruedCap(enableMaximumRewardAccruedCap);
    }

    /**
     * @notice Function to set the share of the epoch reward to be given out to treasury
     * @param multiSigRewardShare_ New multiSig reward share in 5s
     */
    function setMultiSigRewardShare(uint256 multiSigRewardShare_)
        external
        onlyOwner
    {
        multiSigRewardShare = multiSigRewardShare_;
        emit LogSetMultiSigRewardShare(multiSigRewardShare);
    }

    /**
     * @notice Function to set the multiSig treasury address to get treasury rewards
     * @param multiSigRewardAddress New multi sig treasury address
     */
    function setMultiSigRewardAddress(address multiSigRewardAddress_) external onlyOwner {
        multiSigRewardAddress = multiSigRewardAddress_;
        emit LogSetMultiSigRewardAddress(multiSigRewardAddress);
    }

    /**
     * @notice Function to set the reward duration for a single epoch reward period
     * @param couponRewardBlockPeriod_ New block duration period
     */
    function setCouponRewardBlockPeriod(uint256 couponRewardBlockPeriod_)
        external
        onlyOwner
    {
        couponRewardBlockPeriod = couponRewardBlockPeriod_;
        emit LogSetRewardBlockPeriod(couponRewardBlockPeriod);
    }

    /**
     * @notice Function to set the reward duration for a single epoch reward period
     * @param depositRewardBlockPeriod_ New block duration period
     */
    function setdepositRewardBlockPeriod(uint256 depositRewardBlockPeriod_)
        external
        onlyOwner
    {
        depositRewardBlockPeriod = depositRewardBlockPeriod_;
        emit LogSetRewardBlockPeriod(depositRewardBlockPeriod);
    }

    /**
     * @notice Function to set the mean,deviation and formula constants for log normals curve
     * @param mean_ New log normal mean
     * @param deviation_ New log normal deviation
     * @param peakScaler_ New peak scaler value
     * @param oneDivDeviationSqrtTwoPi_ New Result of 1/(Deviation*Sqrt(2*pi))
     * @param twoDeviationSquare_ New Result of 2*(Deviation)^2
     */
    function setMeanAndDeviationWithFormulaConstants(
        bytes16 mean_,
        bytes16 deviation_,
        bytes16 peakScaler_,
        bytes16 oneDivDeviationSqrtTwoPi_,
        bytes16 twoDeviationSquare_
    ) external onlyOwner {
        mean = mean_;
        deviation = deviation_;
        peakScaler = peakScaler_;
        oneDivDeviationSqrtTwoPi = oneDivDeviationSqrtTwoPi_;
        twoDeviationSquare = twoDeviationSquare_;

        emit LogSetMeanAndDeviationWithFormulaConstants(
            mean,
            deviation,
            peakScaler,
            oneDivDeviationSqrtTwoPi,
            twoDeviationSquare
        );
    }

    // Struct saving the data related rebase cycles
    struct CouponCycle {
        // Shows the %s of the totalSupply to be given as reward
        uint256 rewardShare;
        // The uwu to be rewarded as per the epoch
        uint256 uwuPerEpoch;
        // The number of blocks to give out rewards per epoch
        uint256 rewardBlockPeriod;
        // Shows the number of epoch(rebases) to distribute rewards for
        uint256 epochsToReward;
        // Flag to start deposit distibution from previous cycle
        uint256 epochsRewarded;
        // The number if coupouns issued/UwU sold in the contraction cycle
        uint256 totalBalance;
        // The reward Rate for the distribution cycle
        uint256 rewardRate;
        uint256 periodFinish;
        uint256 lastUpdateBlock;
        uint256 rewardPerTokenStored;
        mapping(address => uint256) userBalance;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
        uint256 rewardsDistributed;
    }

    struct OracleCycle {
        // Flag to enable or disable coupon buying
        bool couponBuying;
        // The number of blocks coupons can be bought
        uint256 oracleBuyBlockPeriod;
        // The number of blocks coupons cant be bought
        uint256 oracleLockBlockPeriod;
        // Last Price of the oracle used to open or close coupon buying
        uint256 oracleLastPrice;
        // The block number when the oracle with update next
        uint256 oracleNextUpdate;
    }

    struct DepositCycle {
        // The number if coupouns issued/UwU sold in the contraction cycle
        bool started;
        uint256 rewardBlockPeriod;
        uint256 totalBalance;
        // The reward Rate for the distribution cycle
        uint256 rewardRate;
        uint256 periodFinish;
        uint256 lastUpdateBlock;
        uint256 rewardPerTokenStored;
        mapping(address => uint256) userBalance;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
        uint256 rewardsDistributed;
    }

    // Array of rebase cycles
    CouponCycle[] public couponCycles;

    // Array of rebase cycles
    DepositCycle[] public depositCycles;

    //Arry of oracle cycles
    OracleCycle[] public oracleCycles;

    // Lenght of the rebase cycles
    uint256 public cyclesLength;

    modifier checkArrayAndIndex(uint256 index) {
        require(cyclesLength != 0, "Cycle array is empty");
        require(
            index <= cyclesLength.sub(1),
            "Index should not me more than items in the cycle array"
        );
        _;
    }

    /**
     * @notice Function that initializes set of variables for the pool on launch
     */
    function initialize(
        IUwU uwu_,
        IOracle oracle_,
        IUwUPolicy policy_,
        address burnPool1_,
        address burnPool2_,
        uint256 epochs_,
        uint256 curveShifter_,
        uint256 initialRewardShare_,
        address multiSigRewardAddress_,
        uint256 multiSigRewardShare_,
        bytes16 mean_,
        bytes16 deviation_,
        bytes16 oneDivDeviationSqrtTwoPi_,
        bytes16 twoDeviationSquare_
    ) external initializer onlyOwner {
        uwu = uwu_;
        burnPool1 = burnPool1_;
        burnPool2 = burnPool2_;
        policy = policy_;
        oracle = oracle_;

        epochs = epochs_;
        curveShifter = curveShifter_;
        mean = mean_;
        deviation = deviation_;
        oneDivDeviationSqrtTwoPi = oneDivDeviationSqrtTwoPi_;
        twoDeviationSquare = twoDeviationSquare_;
        initialRewardShare = initialRewardShare_;
        multiSigRewardShare = multiSigRewardShare_;
        multiSigRewardAddress = multiSigRewardAddress_;

        lastRebase = Rebase.NONE;
    }
}
