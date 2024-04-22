// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {IHashes} from "./interfaces/IHashes.sol";
import {IHashesDAO} from "./interfaces/IHashesDAO.sol";

/// @title Redemption
/// @notice A Redemption contract for the Hashes system. This Redemption
///         contract is funded with ether and allows Hashes tokens to be
///         redeemed for the funded ether before a deadline.
contract Redemption is ReentrancyGuard {
    /// @notice The cap for the DEX Labs Hashes.
    uint256 public constant DEX_LABS_CAP = 100;

    /// @notice The hashes contract used by the this redemption contract.
    IHashes public constant HASHES =
        IHashes(address(0xD07e72b00431af84AD438CA995Fd9a7F0207542d));

    /// @notice The HashesDAO contract that the ETH in the redemption will be
    ///         returned to after the deadline has passed.
    IHashesDAO public constant HASHES_DAO =
        IHashesDAO(address(0xbD3Af18e0b7ebB30d49B253Ab00788b92604552C));

    /// @notice The deadline to redeem a hash. Redemptions are considered
    ///         finalized after this deadline and funds can be moved back into
    ///         the hashes DAO.
    uint256 public immutable deadline;

    /// @notice The total amount of ether that is eligible to be redeemed.
    uint256 public totalFunding;

    /// @notice The total number of commitments that were submitted. This is
    ///         used to determine the amount of ETH that each committed Hash
    ///         should receive.
    uint256 public totalCommitments;

    /// @notice The commitments that have been processed. This is mapping from
    ///         token ID to the address that submitted the commitment.
    mapping(uint256 => address) public commitments;

    /// @notice A flag indicating whether or not unused funds have been drawn
    ///         back to the HashesDAO.
    bool public wasDrawn;

    /// @notice Thrown when the duration is invalid.
    error InvalidDuration();

    /// @notice Thrown when the current timestamp is after the deadline but the
    ///         function can only be called before the deadline.
    error AfterDeadline();

    /// @notice Thrown when the current timestamp is before the deadline but the
    ///         function can only be called after the deadline.
    error BeforeDeadline();

    /// @notice Thrown when the token IDs aren't monotonically increasing.
    error UnsortedTokenIds();

    /// @notice Thrown when the hash isn't eligible for redemption.
    error IneligibleHash();

    /// @notice Thrown when a hash wasn't committed by the sender or wasn't
    ///         committed at all.
    error UncommittedHash();

    /// @notice Thrown when ether can't be transferred.
    error TransferFailed();

    /// @notice Instantiates the Hashes redemption contract.
    /// @param _duration The duration of the redemption.
    constructor(uint256 _duration) {
        // Ensure that the duration is greater than zero.
        if (_duration == 0) {
            revert InvalidDuration();
        }

        // Initialize the deadline.
        deadline = block.timestamp + _duration;
    }

    modifier beforeDeadline() {
        if (block.timestamp >= deadline) {
            revert AfterDeadline();
        }
        _;
    }

    modifier afterDeadline() {
        if (block.timestamp < deadline) {
            revert BeforeDeadline();
        }
        _;
    }

    /// @notice Allows the contract to receive ether before the deadline.
    receive() external payable beforeDeadline {
        // Increase the total funding by the message value.
        totalFunding += msg.value;
    }

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
        uint256 governanceCap = HASHES.governanceCap();
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // Ensure that the current token ID is either the first token ID to
            // be processed or is strictly greater than the last token ID.
            if (i != 0 && _tokenIds[i] <= lastTokenId) {
                revert UnsortedTokenIds();
            }
            lastTokenId = _tokenIds[i];

            // Ensure that the token ID refers to an active DAO hash that is
            // not a DEX Labs Hash.
            if (
                lastTokenId < DEX_LABS_CAP ||
                lastTokenId >= governanceCap ||
                HASHES.deactivated(lastTokenId)
            ) {
                revert IneligibleHash();
            }

            // Take custody of the Hashes token.
            HASHES.transferFrom(msg.sender, address(this), lastTokenId);

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
            if (i != 0 && _tokenIds[i] <= lastTokenId) {
                revert UnsortedTokenIds();
            }
            lastTokenId = _tokenIds[i];

            // Ensure that the token ID refers to a commitment owned by the
            // sender.
            if (commitments[lastTokenId] != msg.sender) {
                revert UncommittedHash();
            }

            // Revoke the commitment.
            totalCommitments -= 1;
            commitments[lastTokenId] = address(0);

            // Transfer the Hash to the sender.
            HASHES.transferFrom(address(this), msg.sender, lastTokenId);
        }
    }

    /// @notice Redeems a set of Hashes from redemption.
    /// @param _tokenIds The token IDs to redeem.
    function redeem(
        uint256[] calldata _tokenIds
    ) external nonReentrant afterDeadline {
        // Iterate over the list of token IDs. The token IDs should be
        // monotonically increasing and should refer to Hashes that have already
        // been committed. If either of these conditions are violated, we revert.
        uint256 lastTokenId;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // Ensure that the current token ID is either the first token ID to
            // be processed or is strictly greater than the last token ID.
            if (i != 0 && _tokenIds[i] <= lastTokenId) {
                revert UnsortedTokenIds();
            }
            lastTokenId = _tokenIds[i];

            // Ensure that the token ID refers to a commitment owned by the
            // sender.
            if (commitments[lastTokenId] != msg.sender) {
                revert UncommittedHash();
            }

            // Reset the commitment to prevent double spends.
            commitments[lastTokenId] = address(0);
        }

        // The amount of ether that the sender will receive is calculated as:
        //
        // redeemAmount = _tokenIds.length * min(
        //     balance / totalCommitments,
        //     1 ether
        // )
        //
        // To increase the precision of the calculation, we process the
        // multiplication before the division.
        uint256 redeemAmount = min(
            (_tokenIds.length * totalFunding) / totalCommitments,
            _tokenIds.length * 1 ether
        );
        (bool success, ) = msg.sender.call{value: redeemAmount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /// @notice Allows anyone to transfer any ether that isn't needed to process
    ///         redemptions to the DAO.
    function draw() external nonReentrant afterDeadline {
        // If funds have already been drawn, we can exit early.
        if (wasDrawn) {
            return;
        }

        // Set the flag to indicate that funds were drawn.
        wasDrawn = true;

        // If the price per commitment is less than one ether, all of the ether
        // will be consumed by redemptions, and we can exit early.
        if (totalFunding / totalCommitments <= 1 ether) {
            return;
        }

        // The amount of ether that can be returned to the DAO is given by:
        //
        // unusedFunds = totalFunding - totalCommitments * 1 ether
        //
        // If the unused funds amount is greater than zero, we transfer the
        // unused funds to the hashes DAO.
        uint256 redeemFunds = totalCommitments * 1 ether;
        if (totalFunding > redeemFunds) {
            // Transfer the unused funds to the HashesDAO.
            (bool success, ) = address(HASHES_DAO).call{
                value: totalFunding - redeemFunds
            }("");
            if (!success) {
                revert TransferFailed();
            }
        }
    }

    /// @notice Allows anyone to reclaim hashes to the HashesDAO.
    /// @param _tokenIds The token IDs to reclaim.
    function reclaim(
        uint256[] calldata _tokenIds
    ) external nonReentrant afterDeadline {
        // Iterate over the list of token IDs. The token IDs should be
        // monotonically increasing. If the list of token IDs isn't
        // monotonically increasing, we revert. Assuming the list is sorted,
        // the Hashes are transferred to the HashesDAO contract.
        uint256 lastTokenId;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // Ensure that the current token ID is either the first token ID to
            // be processed or is strictly greater than the last token ID.
            if (i != 0 && _tokenIds[i] <= lastTokenId) {
                revert UnsortedTokenIds();
            }
            lastTokenId = _tokenIds[i];

            // Transfer the Hash to the HashesDAO.
            HASHES.transferFrom(
                address(this),
                address(HASHES_DAO),
                lastTokenId
            );
        }
    }

    /// @dev Gets the minimum of two numbers.
    /// @param _a The first value.
    /// @param _b The second value.
    /// @return The minimum value.
    function min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
