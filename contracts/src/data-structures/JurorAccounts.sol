// SPDX-License-Identifier: MIT

/**
 *  @authors: [@unknownunknown1, @jaybuidl]
 *  @reviewers: []
 *  @auditors: []
 *  @bounties: []
 *  @deployments: []
 */

pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC20SafeTransfer.sol";

uint256 constant MAX_STAKE_PATHS = 4; // The maximum number of stake paths a juror can have.

/**
 *  @title Jurors
 *  @dev A library that keeps track of the jurors stakes.
 */
library JurorAccounts {
    using ERC20SafeTransfer for IERC20;

    /* Structs */

    struct Juror {
        uint96[] subcourtIDs; // The IDs of subcourts where the juror's stake path ends. A stake path is a path from the general court to a court the juror directly staked in using `_setStake`.
        mapping(uint96 => uint256) stakedTokens; // The number of tokens the juror has staked in the subcourt in the form `stakedTokens[subcourtID]`.
        mapping(uint96 => uint256) lockedTokens; // The number of tokens the juror has locked in the subcourt in the form `lockedTokens[subcourtID]`.
    }

    struct DelayedStake {
        address account; // The address of the juror.
        uint96 subcourtID; // The ID of the subcourt.
        uint256 stake; // The new stake.
        uint256 penalty; // Penalty value, in case the stake was set during execution.
    }

    /* Storage */

    struct Jurors {
        mapping(address => Juror) jurors;
        mapping(uint256 => DelayedStake) delayedStakes; // Stores the stakes that were changed during Freezing phase, to update them when the phase is switched to Staking.
        uint256 delayedStakeWriteIndex; // The index of the last `delayedStake` item that was written to the array. 0 index is skipped.
        uint256 delayedStakeReadIndex; // The index of the next `delayedStake` item that should be processed. Starts at 1 because 0 index is skipped.
        IERC20 pinakion; // The Pinakion token contract.
        bool initialized;
    }

    function initialize(Jurors storage self, IERC20 _pinakion) external {
        require(!self.initialized, "Already initialized.");
        self.delayedStakeReadIndex = 1;
        self.pinakion = _pinakion;
        self.initialized = true;
    }

    function lockTokens(
        Jurors storage self,
        address _juror,
        uint96 _subcourtID,
        uint256 _amount
    ) external {
        self.jurors[_juror].lockedTokens[_subcourtID] += _amount;
    }

    function unlockTokens(
        Jurors storage self,
        address _juror,
        uint96 _subcourtID,
        uint256 _amount
    ) external {
        self.jurors[_juror].lockedTokens[_subcourtID] -= _amount;
    }

    function getBalance(
        Jurors storage self,
        address _juror,
        uint96 _subcourtID
    ) external view returns (uint256 staked, uint256 locked) {
        Juror storage juror = self.jurors[_juror];
        staked = juror.stakedTokens[_subcourtID];
        locked = juror.lockedTokens[_subcourtID];
    }

    function getStakedSubcourts(Jurors storage self, address _juror)
        external
        view
        returns (uint96[] memory subcourtIDs)
    {
        return self.jurors[_juror].subcourtIDs;
    }

    function setStakeForAccount(
        Jurors storage self,
        address _account,
        uint96 _subcourtID,
        uint256 _currentStake,
        uint256 _newStake,
        uint256 _penalty,
        bool _delayed
    ) public returns (bool, uint256) {
        Juror storage juror = self.jurors[_account];
        if (_newStake != 0) {
            // Check against locked tokens in case the min stake was lowered.
            if (_newStake < juror.lockedTokens[_subcourtID]) return (false, 0);
            if (_currentStake == 0 && juror.subcourtIDs.length >= MAX_STAKE_PATHS) return (false, 0);
        }

        // Delayed action logic.
        if (_delayed) {
            self.delayedStakes[++self.delayedStakeWriteIndex] = DelayedStake({
                account: _account,
                subcourtID: _subcourtID,
                stake: _newStake,
                penalty: _penalty
            });
            return (true, 0);
        }

        uint256 transferredAmount;
        if (_newStake >= _currentStake) {
            transferredAmount = _newStake - _currentStake;
            if (transferredAmount > 0) {
                if (self.pinakion.safeTransferFrom(_account, address(this), transferredAmount)) {
                    if (_currentStake == 0) {
                        juror.subcourtIDs.push(_subcourtID);
                    }
                } else {
                    return (false, 0);
                }
            }
        } else if (_newStake == 0) {
            // Keep locked tokens in the contract and release them after dispute is executed.
            transferredAmount = _currentStake - juror.lockedTokens[_subcourtID] - _penalty;
            if (transferredAmount > 0) {
                if (self.pinakion.safeTransfer(_account, transferredAmount)) {
                    for (uint256 i = 0; i < juror.subcourtIDs.length; i++) {
                        if (juror.subcourtIDs[i] == _subcourtID) {
                            juror.subcourtIDs[i] = juror.subcourtIDs[juror.subcourtIDs.length - 1];
                            juror.subcourtIDs.pop();
                            break;
                        }
                    }
                } else {
                    return (false, 0);
                }
            }
        } else {
            transferredAmount = _currentStake - _newStake - _penalty;
            if (transferredAmount > 0) {
                if (!self.pinakion.safeTransfer(_account, transferredAmount)) {
                    return (false, 0);
                }
            }
        }

        // Update juror's records.
        uint256 newTotalStake = juror.stakedTokens[_subcourtID] - _currentStake + _newStake;
        juror.stakedTokens[_subcourtID] = newTotalStake;

        return (true, newTotalStake);
    }

    function readDelayedStakes(Jurors storage self, uint256 _iterations)
        external
        returns (uint256 startIndex, uint256 stopIndex)
    {
        startIndex = self.delayedStakeReadIndex;

        // Ensure that (readIndex <= writeIndex) so increment by min(iterations, writeIndex - readIndex + 1)
        self.delayedStakeReadIndex += (self.delayedStakeReadIndex + _iterations) - 1 > self.delayedStakeWriteIndex
            ? (self.delayedStakeWriteIndex - self.delayedStakeReadIndex) + 1
            : _iterations;

        stopIndex = self.delayedStakeReadIndex - 1;
    }

    function popDelayedStake(Jurors storage self, uint256 _index)
        external
        returns (
            address account,
            uint96 subcourtID,
            uint256 stake,
            uint256 penalty
        )
    {
        DelayedStake storage delayedStake = self.delayedStakes[_index];
        account = delayedStake.account;
        subcourtID = delayedStake.subcourtID;
        stake = delayedStake.stake;
        penalty = delayedStake.penalty;
        delete self.delayedStakes[_index];
    }
}
