// SPDX-License-Identifier: MIT
/*

██╗   ██╗██╗    ██╗██╗   ██╗
██║   ██║██║    ██║██║   ██║
██║   ██║██║ █╗ ██║██║   ██║
██║   ██║██║███╗██║██║   ██║
╚██████╔╝╚███╔███╔╝╚██████╔╝
 ╚═════╝  ╚══╝╚══╝  ╚═════╝ 
                            
* UwU: BridgPool.sol
* Description:
* Pool that bridges eth assets into bsc and mines them for UwU
* Coded by: punkUnknown
*/

pragma solidity >=0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgePool is Ownable, Initializable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;
    uint256 public duration;
    bool public poolEnabled;

    uint256 public initReward;
    uint256 public maxReward;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public rewardDistributed;
    uint256 private _totalSupply;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event PoolEnabled(uint256 startedAt);

    modifier enabled() {
        require(poolEnabled, "Pool isn't enabled");
        _;
    }

    modifier checkHalve() {
        if (block.timestamp >= periodFinish) {
            initReward = initReward.mul(50).div(100);

            rewardRate = initReward.div(duration);
            periodFinish = block.timestamp.add(duration);
            emit RewardAdded(initReward);
        }
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function initialize(address rewardToken_, uint256 duration_)
        external
        initializer
    {
        rewardToken = IERC20(rewardToken_);
        maxReward = rewardToken.balanceOf(address(this));
        duration = duration_;
    }

    function startPool() external onlyOwner {
        require(!poolEnabled, "Pool can only be started once");
        poolEnabled = true;
        startNewDistribtionCycle(maxReward.mul(50).div(100));
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(10**18)
                    .div(totalSupply())
            );
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(10**18)
                .add(rewards[account]);
    }

    function stake(address user, uint256 amount)
        external
        updateReward(msg.sender)
        onlyOwner
        checkHalve
    {
        _totalSupply = _totalSupply.add(amount);
        balances[user] = balances[user].add(amount);
    }

    function getReward() public updateReward(msg.sender) enabled checkHalve {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            rewardDistributed = rewardDistributed.add(reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function startNewDistribtionCycle(uint256 reward)
        internal
        updateReward(address(0))
    {
        initReward = reward;
        rewardRate = reward.div(duration);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(duration);
        emit RewardAdded(reward);
    }
}
