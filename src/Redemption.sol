// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {IHashes} from "./interfaces/IHashes.sol";
import {IHashesDAO} from "./interfaces/IHashesDAO.sol";

/// @title Redemption
/// @notice A Redemption contract for the Hashes system. This Redemption
///         contract is funded with ether and allows Hashes tokens to be
///         redeemed for the funded ether before a deadline.
contract Redemption is ReentrancyGuard {
    /// @notice The Hashes contract used by this redemption contract.
    IHashes public immutable hashes;

    /// @notice The HashesDAO contract that the ETH in the redemption will be
    ///         returned to after the deadline has passed.
    IHashesDAO public immutable hashesDAO;

    /// @notice The deadline to redeem a hash. Redemptions are considered
    ///         finalized after this deadline and funds can be moved back into
    ///         the hashes DAO.
    uint256 public immutable deadline;

    /// @notice The total number of commitments that were submitted. This is
    ///         used to determine the amount of ETH that each committed Hash
    ///         should receive.
    uint256 public totalCommitments;

    /// @notice The commitments that have been processed. This is mapping from
    ///         token ID to the address that submitted the commitment.
    mapping(uint256 => address) public commitments;

    /// @notice Instantiates the Hashes redemption contract.
    /// @param _hashes The Hashes token.
    /// @param _hashesDAO The HashesDAO.
    /// @param _duration The duration of the redemption.
    constructor(
        IHashes _hashes,
        IHashesDAO _hashesDAO,
        uint256 _duration
    ) payable {
        // Ensure that the HashesDAO address is non-zero.
        require(
            address(_hashesDAO) != address(0),
            "Redemption: Invalid HashesDAO."
        );

        // Ensure that the Hashes token is tracked by governance.
        require(
            _hashesDAO.hashesToken() == _hashes,
            "Redemption: Invalid Hashes token."
        );

        // Ensure that the duration is greater than zero.
        require(_duration > 0, "Redemption: Invalid duration.");

        // Initialize the immutables.
        hashes = _hashes;
        hashesDAO = _hashesDAO;
        deadline = block.timestamp + _duration;
    }

    modifier beforeDeadline() {
        require(
            block.timestamp < deadline,
            "Redemption: The deadline has passed."
        );
        _;
    }

    modifier afterDeadline() {
        require(
            block.timestamp >= deadline,
            "Redemption: The deadline hasn't passed yet."
        );
        _;
    }

    /// @notice Allows the contract to receive ether before the deadline.
    receive() external payable beforeDeadline {}

    /// @notice Commits a set of Hashes for redemption.
    /// @param _tokenIds The token IDs to commit for redemption.
    function commit(
        uint256[] calldata _tokenIds
    ) external nonReentrant beforeDeadline {
        // Iterate over the list of token IDs. The token IDs should be
        // monotonically increasing, should refer to DAO hashes, and should
        // refer to Hashes that haven't been deactivated. If any of these
        // conditions are violated, we revert. Assuming all of the conditions
        // hold, we take custody of the Hashes token and add the token to the
        // list of commitments.
        uint256 lastTokenId;
        uint256 governanceCap = hashes.governanceCap();
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // Ensure that the current token ID is either the first token ID to
            // be processed or is strictly greater than the last token ID.
            require(
                i == 0 || _tokenIds[i] > lastTokenId,
                "Redemption: The token IDs aren't monotonically increasing."
            );
            lastTokenId = _tokenIds[i];

            // Ensure that the token ID refers to an active DAO hash.
            require(
                lastTokenId < governanceCap && !hashes.deactivated(lastTokenId),
                "Redemption: Token ID refers to a non-DAO hash or a deactivated DAO hash."
            );

            // Take custody of the Hashes token.
            hashes.safeTransferFrom(msg.sender, address(this), lastTokenId);

            // Process the commitment.
            totalCommitments += 1;
            commitments[lastTokenId] = msg.sender;
        }
    }

    /// @notice Revokes a set of Hashes from redemption.
    /// @param _tokenIds The token IDs to revoke from redemption.
    function revoke(
        uint256[] calldata _tokenIds
    ) external nonReentrant beforeDeadline {
        // Iterate over the list of token IDs. The token IDs should be
        // monotonically increasing and should refer to Hashes that have already
        // been committed. If either of these conditions are violated, we revert.
        // Assuming all of the conditions hold, the Hashes tokens are
        // transferred to the revoker and the commitments are revoked.
        uint256 lastTokenId;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // Ensure that the current token ID is either the first token ID to
            // be processed or is strictly greater than the last token ID.
            require(
                i == 0 || _tokenIds[i] > lastTokenId,
                "Redemption: The token IDs aren't monotonically increasing."
            );
            lastTokenId = _tokenIds[i];

            // Ensure that the token ID refers to a commitment owned by the
            // sender.
            require(
                commitments[lastTokenId] == msg.sender,
                "Redemption: Token ID doesn't refer to a commitment."
            );

            // Revoke the commitment.
            totalCommitments -= 1;
            commitments[lastTokenId] = address(0);

            // Transfer the Hash to the sender.
            hashes.transferFrom(address(this), msg.sender, lastTokenId);
        }
    }

    // FIXME
    function redeem() external nonReentrant afterDeadline {}
}
