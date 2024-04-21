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

    Redemption internal redemption;

    function setUp() external {
        // Create a mainnet fork.
        uint256 mainnetForkId = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetForkId);
        vm.rollFork(MAINNET_FORK_BLOCK);

        // Deploy the Redemption contract.
        redemption = new Redemption(DURATION);
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
}
