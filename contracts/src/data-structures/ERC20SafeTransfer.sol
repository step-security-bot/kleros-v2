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

/**
 *  @title Jurors
 *  @dev A library that keeps track of the jurors stakes.
 */
library ERC20SafeTransfer {
    /** @dev Calls transfer() without reverting.
     *  @param _to Recepient address.
     *  @param _value Amount transferred.
     *  @return Whether transfer succeeded or not.
     */
    function safeTransfer(
        IERC20 self,
        address _to,
        uint256 _value
    ) internal returns (bool) {
        (bool success, bytes memory data) = address(self).call(
            abi.encodeWithSelector(IERC20.transfer.selector, _to, _value)
        );
        return (success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /** @dev Calls transferFrom() without reverting.
     *  @param _from Sender address.
     *  @param _to Recepient address.
     *  @param _value Amount transferred.
     *  @return Whether transfer succeeded or not.
     */
    function safeTransferFrom(
        IERC20 self,
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool) {
        (bool success, bytes memory data) = address(self).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _value)
        );
        return (success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
