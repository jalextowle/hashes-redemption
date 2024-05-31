// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {Redemption} from "src/Redemption.sol";

contract DeploymentScript is Script {
    uint256 internal constant DURATION = 35 days;

    function run() external {
        vm.startBroadcast();

        // Deploy the redemption contract.
        Redemption redemption = new Redemption(DURATION);
        console.log(
            "deployed the redemption contract to %s",
            address(redemption)
        );

        // Ensure that the deadline is correct.
        require(
            redemption.deadline() == block.timestamp + DURATION,
            "incorrect deadline"
        );

        vm.stopBroadcast();
    }
}
