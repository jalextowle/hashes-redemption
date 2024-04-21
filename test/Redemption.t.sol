// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Redemption} from "src/Redemption.sol";
import {IHashes} from "src/interfaces/IHashes.sol";
import {IHashesDAO} from "src/interfaces/IHashesDAO.sol";

contract RedemptionTest is Test {
    uint256 internal constant DURATION = 30 days;

    uint256 internal constant MAINNET_FORK_BLOCK = 19705328;
    string internal MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address internal constant FUNDER = address(0xdeadbeef);

    Redemption internal redemption;

    function setUp() external {
        // Create a mainnet fork.
        uint256 mainnetForkId = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetForkId);
        vm.rollFork(MAINNET_FORK_BLOCK);

        // Deploy the redemption contract.
        redemption = new Redemption(DURATION);

        // Fund the redemption contract with the expected amount of ether.
        vm.startPrank(FUNDER);
        uint256 fundingAmount = 542.979 ether;
        vm.deal(FUNDER, fundingAmount);
        (bool success, ) = address(redemption).call{value: fundingAmount}("");
        require(success, "couldn't fund the redemption contract");
    }

    /// Constructor Tests ///

    function test__constructor__failure__invalidDuration() external {
        vm.expectRevert(Redemption.InvalidDuration.selector);
        new Redemption(0);
    }

    function test__constructor__success() external {
        // Deploy the redemption contract with a duration of one year.
        uint256 currentBlockTime = block.timestamp;
        uint256 duration = 365 days;
        redemption = new Redemption(duration);

        // Ensure that the deadline is properly configured.
        assertEq(redemption.deadline(), currentBlockTime + duration);
    }

    /// Receive Tests ///

    function test__receive__failure__afterDeadline() external {
        // Increase the time to the deadline.
        vm.warp(redemption.deadline());

        // Increase the funder's balance of ether.
        vm.deal(FUNDER, 1_000e18);

        // Attempting to send ether to the contract at the deadline should fail.
        (bool success, bytes memory returndata) = address(redemption).call{
            value: 1_000e18
        }("");
        assertEq(success, false);
        assertEq(
            returndata,
            abi.encodeWithSelector(Redemption.AfterDeadline.selector)
        );

        // Increase the time to the deadline.
        vm.warp(redemption.deadline());

        // Attempting to send ether to the contract after the deadline should fail.
        (success, returndata) = address(redemption).call{value: 1_000e18}("");
        assertEq(success, false);
        assertEq(
            returndata,
            abi.encodeWithSelector(Redemption.AfterDeadline.selector)
        );
    }

    function test__receive__success() external {
        // Increase the funder's balance of ether.
        vm.deal(FUNDER, 1_000e18);

        // Sending ether to the contract before the deadline should succeed.
        (bool success, ) = address(redemption).call{value: 1_000e18}("");
        assertEq(success, true);

        // The contract's total funding should be equal to its balance of ether.
        assertEq(redemption.totalFunding(), address(redemption).balance);
    }
}
