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
import "./interfaces/IUwU.sol";
import "./interfaces/IUwUPolicy.sol";
import "./interfaces/IPool.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

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

    IPool public uwuDaiPool;
    IPool public uwuDaiLpPool;

    IPool public degovDaiLpPool;
    bool public rebaseStarted;
    uint256 public maximumRebaseTime;
    uint256 public rebaseRequiredSupply;

    event LogRebaseStarted(uint256 timeStarted);
    event LogAddNewUniPair(address token1, address token2);

    uint256 constant SYNC_GAS = 50000;
    address constant uniFactory = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;

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

    // https://uniswap.org/docs/v2/smart-contract-integration/getting-pair-addresses/
    function genUniAddr(address left, address right)
        internal
        pure
        returns (IUniswapV2Pair)
    {
        address first = left < right ? left : right;
        address second = left < right ? right : left;
        address pair =
            address(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            uniFactory,
                            keccak256(abi.encodePacked(first, second)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"
                        )
                    )
                )
            );
        return IUniswapV2Pair(pair);
    }

    function initialize(
        address uwu_,
        address uwuPolicy_,
        address uwuDaiPool_,
        address uwuDaiLpPool_,
        address degovDaiLpPool_,
        uint256 rebaseRequiredSupply_,
        uint256 oracleStartTimeOffset
    ) external initializer {
        uwu = IUwU(uwu_);
        uwuPolicy = IUwUPolicy(uwuPolicy_);

        uwuDaiPool = IPool(uwuDaiPool_);
        uwuDaiLpPool = IPool(uwuDaiLpPool_);
        degovDaiLpPool = IPool(degovDaiLpPool_);

        maximumRebaseTime = block.timestamp + oracleStartTimeOffset;
        rebaseStarted = false;
        rebaseRequiredSupply = rebaseRequiredSupply_;
    }

    function addUniPair(address token1, address token2) external onlyOwner {
        uniSyncs.push(UniPair(true, genUniAddr(token1, token2)));

        emit LogAddNewUniPair(token1, token2);
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
        // Rebase will only be called when 95% of the total supply has been distributed or current time is 3 weeks since the orchestrator was deployed.
        // To stop the rebase from getting stuck if no enough rewards are distributed. This will also start the degov/uwu pool reward drops
        if (!rebaseStarted) {
            uint256 rewardsDistributed =
                uwuDaiPool.rewardDistributed().add(
                    uwuDaiLpPool.rewardDistributed()
                );

            require(
                rewardsDistributed >= rebaseRequiredSupply ||
                    block.timestamp >= maximumRebaseTime,
                "Not enough rewards distributed or time less than start time"
            );

            //Start degov reward drop
            degovDaiLpPool.startPool();
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
