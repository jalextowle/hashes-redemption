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

    /// Commit Tests ///

    function test__commit__failure__afterDeadline() external {
        // Impersonate the owner of a DAO hash that isn't a DEX Labs hash and
        // approve the redemption contract for all.
        uint256 tokenId = 100;
        vm.startPrank(redemption.HASHES().ownerOf(tokenId));
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Committing the Hash should fail since the deadline has been reached.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        vm.expectRevert(Redemption.AfterDeadline.selector);
        redemption.commit(tokenIds);

        // Warp after the deadline.
        vm.warp(redemption.deadline() + 30 days);

        // Committing the Hash should fail since the deadline has been reached.
        vm.expectRevert(Redemption.AfterDeadline.selector);
        redemption.commit(tokenIds);
    }

    function test__commit__failure__duplicateTokenIds() external {
        // Impersonate the owner of a DAO hash that isn't a DEX Labs hash and
        // approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing the Hash should fail since the token IDs are duplicated.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 259;
        tokenIds[1] = 259;
        vm.expectRevert(Redemption.UnsortedTokenIds.selector);
        redemption.commit(tokenIds);
    }

    function test__commit__failure__unsortedTokenIds() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing the Hash should fail since the token IDs are unsorted.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 304;
        tokenIds[1] = 259;
        vm.expectRevert(Redemption.UnsortedTokenIds.selector);
        redemption.commit(tokenIds);
    }

    function test__commit__failure__dexLabsHash() external {
        // Impersonate the owner of a DEX Labs Hash and approve the redemption
        // contract for all.
        address owner = address(0xEE1DDffcb15C00911d0F78c1A1C75C79b77C5d66);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing the Hash should fail since the token is a DEX Labs Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        vm.expectRevert(Redemption.IneligibleHash.selector);
        redemption.commit(tokenIds);
    }

    function test__commit__failure__nonGovernanceHash() external {
        // Impersonate the owner of a non-governance Hash and approve the
        // redemption contract for all.
        address owner = address(0xF6eb526BFfA8d5036746Df58Fef23Fb091739c44);
        vm.startPrank(owner);

        // Committing the Hash should fail since the token is not a governance
        // Hash.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 4028;
        vm.expectRevert(Redemption.IneligibleHash.selector);
        redemption.commit(tokenIds);
    }

    function test__commit__failure__deactivatedHash() external {
        // Impersonate the owner of a deactivated Hash and approve the
        // redemption contract for all.
        address owner = address(0x9Fe21556009F74244c038e74fb4eAB30FC35cB51);
        vm.startPrank(owner);

        // Committing the Hash should fail since the token is a deactivated
        // Hash.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 829;
        vm.expectRevert(Redemption.IneligibleHash.selector);
        redemption.commit(tokenIds);
    }

    function test__commit__failure__commitTwice() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing a single token ID should succeed.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Ensure that the total committed value increased.
        assertEq(redemption.totalCommitments(), 1);

        // Ensure that the commitment was attributed to the sender.
        assertEq(redemption.commitments(tokenIds[0]), owner);

        // Ensure that the owner of the Hash is now the redemption contract.
        assertEq(redemption.HASHES().ownerOf(tokenIds[0]), address(redemption));

        // Committing the token ID again should fail.
        vm.expectRevert();
        redemption.commit(tokenIds);
    }

    function test__commit__success__emptyTokenIds() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing an empty array should succeed with no effect.
        uint256[] memory tokenIds = new uint256[](0);
        redemption.commit(tokenIds);

        // Ensure that the total committed value didn't change.
        assertEq(redemption.totalCommitments(), 0);
    }

    function test__commit__success__singleTokenId() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing a single token ID should succeed.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Ensure that the total committed value increased.
        assertEq(redemption.totalCommitments(), 1);

        // Ensure that the commitment was attributed to the sender.
        assertEq(redemption.commitments(tokenIds[0]), owner);

        // Ensure that the owner of the Hash is now the redemption contract.
        assertEq(redemption.HASHES().ownerOf(tokenIds[0]), address(redemption));
    }

    function test__commit__success__severalTokenIds() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing several token IDs should succeed.
        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        redemption.commit(tokenIds);

        // Ensure that the total committed value increased.
        assertEq(redemption.totalCommitments(), tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Ensure that the commitment was attributed to the sender.
            assertEq(redemption.commitments(tokenIds[i]), owner);

            // Ensure that the owner of the Hash is now the redemption contract.
            assertEq(
                redemption.HASHES().ownerOf(tokenIds[i]),
                address(redemption)
            );
        }
    }

    function test__commit__success__severalTokenIds__multipleCommits()
        external
    {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Committing several token IDs should succeed.
        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        redemption.commit(tokenIds);

        // Ensure that the total committed value increased.
        assertEq(redemption.totalCommitments(), tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Ensure that the commitment was attributed to the sender.
            assertEq(redemption.commitments(tokenIds[i]), owner);

            // Ensure that the owner of the Hash is now the redemption contract.
            assertEq(
                redemption.HASHES().ownerOf(tokenIds[i]),
                address(redemption)
            );
        }

        // Committing several token IDs should succeed.
        uint256[] memory tokenIds_ = new uint256[](3);
        tokenIds_[0] = 471;
        tokenIds_[1] = 632;
        tokenIds_[2] = 992;
        redemption.commit(tokenIds_);

        // Ensure that the total committed value increased.
        assertEq(
            redemption.totalCommitments(),
            tokenIds.length + tokenIds_.length
        );

        for (uint256 i = 0; i < tokenIds_.length; i++) {
            // Ensure that the commitment was attributed to the sender.
            assertEq(redemption.commitments(tokenIds_[i]), owner);

            // Ensure that the owner of the Hash is now the redemption contract.
            assertEq(
                redemption.HASHES().ownerOf(tokenIds_[i]),
                address(redemption)
            );
        }
    }

    /// Revoke Tests ///

    /// Redeem Tests ///

    /// Draw Tests ///

    /// Reclaim Tests ///
}
