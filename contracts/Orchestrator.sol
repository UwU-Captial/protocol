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

    event LogRebaseStarted(uint256 timeStarted);
    event LogAddNewUniPair(address pair);

    uint256 public syncGas = 100000;

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

    function setSyncGas(uint256 syncGas_) external onlyOwner {
        syncGas = syncGas_;
    }

    function initialize(address uwu_, address uwuPolicy_) external initializer {
        uwu = IUwU(uwu_);
        uwuPolicy = IUwUPolicy(uwuPolicy_);
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
        require(msg.sender == tx.origin); // solhint-disable-line avoid-tx-origin
        uwuPolicy.rebase();

        for (uint256 i = 0; i < uniSyncs.length; i++) {
            if (uniSyncs[i].enabled) {
                address(uniSyncs[i].pair).call{gas: syncGas}(
                    abi.encode(uniSyncs[i].pair.sync.selector)
                );
            }
        }
    }
}
