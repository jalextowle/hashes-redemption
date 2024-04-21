// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {IHashes} from "./interfaces/IHashes.sol";
import {IHashesDAO} from "./interfaces/IHashesDAO.sol";

/// @title Redemption
/// @notice A Redemption contract for the Hashes system. This Redemption
///         contract is funded with ether and allows Hashes tokens to be
///         redeemed for the funded ether before a deadline.
contract Redemption {
    /// @notice The Hashes contract used by this redemption contract.
    IHashes public immutable hashes;

    /// @notice The HashesDAO contract that the ETH in the redemption will be
    ///         returned to after the deadline has passed.
    IHashesDAO public immutable hashesDAO;

    /// @notice The deadline to redeem a hash. Redemptions are considered
    ///         finalized after this deadline and funds can be moved back into
    ///         the hashes DAO.
    uint256 public immutable deadline;

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

    /// @notice Allows the contract to receive ether.
    receive() external payable beforeDeadline {}
}
