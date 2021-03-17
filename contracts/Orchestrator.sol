// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;
/*

██╗   ██╗██╗    ██╗██╗   ██╗
██║   ██║██║    ██║██║   ██║
██║   ██║██║ █╗ ██║██║   ██║
██║   ██║██║███╗██║██║   ██║
╚██████╔╝╚███╔███╔╝╚██████╔╝
 ╚═════╝  ╚══╝╚══╝  ╚═════╝ 
                            
* UwU: Orchestrator.sol
* Description:
* Handles rebases issuance
* Coded by: punkUnknown
*/

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUwU.sol";
import "./interfaces/IUwUPolicy.sol";
import "./interfaces/IPool.sol";
import "./interfaces/ISeed.sol";

/**
 * @title Orchestrator
 * @notice The orchestrator is the main entry point for rebase operations. It coordinates the uwu policy
 *         actions with external consumers.
 */
contract Orchestrator is Ownable, Initializable {
    using SafeMath for uint256;

    // Stable ordering is not guaranteed.
    IUwU public uwu;
    IUwUPolicy public uwuPolicy;

    IPool public debaseBridgePool;
    IPool public debaseEthLpBridgePool;
    IPool public UwUBusdLpPool;
    ISeed public seed;

    bool public rebaseStarted;
    uint256 public maximumRebaseTime;
    uint256 public rebaseRequiredSupply;

    event LogRebaseStarted(uint256 timeStarted);
    event LogAddNewUniPair(address pair);

    uint256 constant SYNC_GAS = 50000;

    struct UniPair {
        bool enabled;
        IUniswapV2Pair pair;
    }

    UniPair[] public uniSyncs;

    modifier indexInBounds(uint256 index) {
        require(
            index < uniSyncs.length,
            "Index must be less than array length"
        );
        _;
    }

    function initialize(
        address uwu_,
        address uwuPolicy_,
        IPool debaseBridgePool_,
        IPool debaseEthLpBridgePool_,
        IPool UwUBusdLpPool_,
        ISeed seed_,
        uint256 rebaseRequiredSupply_,
        uint256 oracleStartTimeOffset
    ) external initializer {
        uwu = IUwU(uwu_);
        uwuPolicy = IUwUPolicy(uwuPolicy_);

        debaseBridgePool = debaseBridgePool_;
        debaseEthLpBridgePool = debaseEthLpBridgePool_;
        UwUBusdLpPool_ = UwUBusdLpPool_;
        seed = seed_;

        maximumRebaseTime = block.timestamp + oracleStartTimeOffset;
        rebaseStarted = false;
        rebaseRequiredSupply = rebaseRequiredSupply_;
    }

    function addUniPair(address pair) external onlyOwner {
        uniSyncs.push(UniPair(true, IUniswapV2Pair(pair)));
        emit LogAddNewUniPair(pair);
    }

    /**
     * @notice Main entry point to initiate a rebase operation.
     *         The Orchestrator calls rebase on the uwu policy and notifies downstream applications.
     *         Contracts are guarded from calling, to avoid flash loan attacks on liquidity
     *         providers.
     *         If a transaction in the transaction list reverts, it is swallowed and the remaining
     *         transactions are executed.
     */
    function rebase() external {
        // Rebase will only be called when 95% of the total supply has been distributed or current time is 2 weeks since the orchestrator was deployed.
        // To stop the rebase from getting stuck if no enough rewards are distributed.
        if (!rebaseStarted) {
            uint256 rewardsDistributed =
                debaseBridgePool
                    .rewardDistributed()
                    .add(debaseEthLpBridgePool.rewardDistributed())
                    .add(UwUBusdLpPool.rewardDistributed())
                    .add(seed.totalUwUDistributed());

            require(
                rewardsDistributed >= rebaseRequiredSupply ||
                    block.timestamp >= maximumRebaseTime,
                "Not enough rewards distributed or time less than start time"
            );

            rebaseStarted = true;
            emit LogRebaseStarted(block.timestamp);
        }
        require(msg.sender == tx.origin); // solhint-disable-line avoid-tx-origin
        uwuPolicy.rebase();

        for (uint256 i = 0; i < uniSyncs.length; i++) {
            if (uniSyncs[i].enabled) {
                address(uniSyncs[i].pair).call{gas: SYNC_GAS}(
                    abi.encode(uniSyncs[i].pair.sync.selector)
                );
            }
        }
    }
}
