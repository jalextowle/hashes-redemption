// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {Redemption} from "src/Redemption.sol";
import {IHashes} from "src/interfaces/IHashes.sol";
import {IHashesDAO} from "src/interfaces/IHashesDAO.sol";

contract RedemptionTest is Test {
    uint256 internal constant DURATION = 30 days;
    uint256 internal constant FUNDING_AMOUNT = 542.97 ether;

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
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Committing the Hash should fail since the deadline has been reached.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
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

        // Ensure that the state was updated correctly.
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

        // Ensure that the state was updated correctly.
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

    function test__revoke__failure__afterDeadline() external {
        // Impersonate the owner of a DAO hash that isn't a DEX Labs hash and
        // approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Revoking the Hash should fail since the deadline has been reached.
        vm.expectRevert(Redemption.AfterDeadline.selector);
        redemption.revoke(tokenIds);

        // Warp after the deadline.
        vm.warp(redemption.deadline() + 30 days);

        // Committing the Hash should fail since the deadline has been reached.
        vm.expectRevert(Redemption.AfterDeadline.selector);
        redemption.revoke(tokenIds);
    }

    function test__revoke__failure__duplicateTokenIds() external {
        // Impersonate the owner of a DAO hash that isn't a DEX Labs hash and
        // approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Revoking the Hash should fail since the token IDs are duplicated.
        uint256[] memory tokenIds_ = new uint256[](2);
        tokenIds_[0] = 259;
        tokenIds_[1] = 259;
        vm.expectRevert(Redemption.UnsortedTokenIds.selector);
        redemption.revoke(tokenIds_);
    }

    function test__revoke__failure__unsortedTokenIds() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        redemption.commit(tokenIds);

        // Revoking the Hash should fail since the token IDs are duplicated.
        uint256[] memory tokenIds_ = new uint256[](2);
        tokenIds_[0] = 304;
        tokenIds_[1] = 259;
        vm.expectRevert(Redemption.UnsortedTokenIds.selector);
        redemption.revoke(tokenIds_);
    }

    function test__revoke__failure__uncommittedHash() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Revoking the Hash before committing should fail.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        vm.expectRevert(Redemption.UncommittedHash.selector);
        redemption.revoke(tokenIds);
    }

    function test__revoke__failure__revokeTwice() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Revoking the Hash should succeed.
        redemption.revoke(tokenIds);

        // Ensure that the total committed value went back to zero.
        assertEq(redemption.totalCommitments(), 0);

        // Ensure that the commitment was reset.
        assertEq(redemption.commitments(tokenIds[0]), address(0));

        // Ensure that the owner of the Hash is the original owner.
        assertEq(redemption.HASHES().ownerOf(tokenIds[0]), owner);

        // Revoking the Hash again should fail.
        vm.expectRevert(Redemption.UncommittedHash.selector);
        redemption.revoke(tokenIds);
    }

    function test__revoke__success__emptyTokenIds() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Revoking an empty array should succeed with no effect.
        uint256[] memory tokenIds = new uint256[](0);
        redemption.revoke(tokenIds);

        // Ensure that the total committed value didn't change.
        assertEq(redemption.totalCommitments(), 0);
    }

    function test__revoke__success__singleTokenId() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Revoking the Hash should succeed.
        redemption.revoke(tokenIds);

        // Ensure that the total committed value went back to zero.
        assertEq(redemption.totalCommitments(), 0);

        // Ensure that the commitment was reset.
        assertEq(redemption.commitments(tokenIds[0]), address(0));

        // Ensure that the owner of the Hash is the original owner.
        assertEq(redemption.HASHES().ownerOf(tokenIds[0]), owner);
    }

    function test__revoke__success__severalTokenIds() external {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit several Hashes.
        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        redemption.commit(tokenIds);

        // Revoking the Hashes should succeed.
        redemption.revoke(tokenIds);

        // Ensure that the total committed value is back to zero.
        assertEq(redemption.totalCommitments(), 0);

        // Ensure that the state was updated correctly.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Ensure that the commitment was reset.
            assertEq(redemption.commitments(tokenIds[i]), address(0));

            // Ensure that the owner of the Hash is the original owner.
            assertEq(redemption.HASHES().ownerOf(tokenIds[i]), owner);
        }
    }

    function test__revoke__success__severalTokenIds__multipleRevokes()
        external
    {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit several Hashes.
        uint256[] memory tokenIds = new uint256[](7);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        tokenIds[4] = 471;
        tokenIds[5] = 632;
        tokenIds[6] = 992;
        redemption.commit(tokenIds);

        // Revoke several Hashes.
        uint256[] memory tokenIds_ = new uint256[](4);
        tokenIds_[0] = 259;
        tokenIds_[1] = 304;
        tokenIds_[2] = 322;
        tokenIds_[3] = 323;
        redemption.revoke(tokenIds_);

        // Ensure that the total committed value decreased.
        assertEq(
            redemption.totalCommitments(),
            tokenIds.length - tokenIds_.length
        );

        // Ensure that the state was updated correctly.
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            // Ensure that the commitment was reset.
            assertEq(redemption.commitments(tokenIds_[i]), address(0));

            // Ensure that the owner of the Hash is the original owner.
            assertEq(redemption.HASHES().ownerOf(tokenIds_[i]), owner);
        }

        // Revoke several more Hashes.
        uint256[] memory tokenIds__ = new uint256[](3);
        tokenIds__[0] = 471;
        tokenIds__[1] = 632;
        tokenIds__[2] = 992;
        redemption.revoke(tokenIds__);

        // Ensure that the total committed value decreased.
        assertEq(
            redemption.totalCommitments(),
            tokenIds.length - tokenIds_.length - tokenIds__.length
        );

        // Ensure that the state was updated correctly.
        for (uint256 i = 0; i < tokenIds__.length; i++) {
            // Ensure that the commitment was reset.
            assertEq(redemption.commitments(tokenIds__[i]), address(0));

            // Ensure that the owner of the Hash is the original owner.
            assertEq(redemption.HASHES().ownerOf(tokenIds__[i]), owner);
        }
    }

    function test__revoke__success__severalTokenIds__repeatedRevokes()
        external
    {
        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit several Hashes.
        uint256[] memory tokenIds = new uint256[](7);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        tokenIds[4] = 471;
        tokenIds[5] = 632;
        tokenIds[6] = 992;
        redemption.commit(tokenIds);

        // Revoke several Hashes.
        redemption.revoke(tokenIds);

        // Ensure that the total committed value is back to zero.
        assertEq(redemption.totalCommitments(), 0);

        // Ensure that the state was updated correctly.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Ensure that the commitment was reset.
            assertEq(redemption.commitments(tokenIds[i]), address(0));

            // Ensure that the owner of the Hash is the original owner.
            assertEq(redemption.HASHES().ownerOf(tokenIds[i]), owner);
        }

        // Commit the Hashes again.
        redemption.commit(tokenIds);

        // Revoke the Hashes again.
        redemption.revoke(tokenIds);

        // Ensure that the total committed value is back to zero.
        assertEq(redemption.totalCommitments(), 0);

        // Ensure that the state was updated correctly.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Ensure that the commitment was reset.
            assertEq(redemption.commitments(tokenIds[i]), address(0));

            // Ensure that the owner of the Hash is the original owner.
            assertEq(redemption.HASHES().ownerOf(tokenIds[i]), owner);
        }
    }

    /// Redeem Tests ///

    function test__redeem__failure__beforeDeadline() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a DAO hash that isn't a DEX Labs hash and
        // approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Redeeming the Hash should fail since the deadline hasn't been reached.
        vm.expectRevert(Redemption.BeforeDeadline.selector);
        redemption.redeem(tokenIds);

        // Warp until right before the deadline.
        vm.warp(redemption.deadline() - 1);

        // Redeeming the Hash should fail since the deadline hasn't been reached.
        vm.expectRevert(Redemption.BeforeDeadline.selector);
        redemption.redeem(tokenIds);
    }

    function test__redeem__failure__duplicateTokenIds() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a DAO hash that isn't a DEX Labs hash and
        // approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Redeeming the Hash should fail since the token IDs are duplicated.
        uint256[] memory tokenIds_ = new uint256[](2);
        tokenIds_[0] = 259;
        tokenIds_[1] = 259;
        vm.expectRevert(Redemption.UnsortedTokenIds.selector);
        redemption.redeem(tokenIds_);
    }

    function test__redeem__failure__unsortedTokenIds() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Redeeming the Hash should fail since the token IDs are duplicated.
        uint256[] memory tokenIds_ = new uint256[](2);
        tokenIds_[0] = 304;
        tokenIds_[1] = 259;
        vm.expectRevert(Redemption.UnsortedTokenIds.selector);
        redemption.redeem(tokenIds_);
    }

    function test__redeem__failure__uncommittedHash() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Redeeming the Hash without committing should fail.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        vm.expectRevert(Redemption.UncommittedHash.selector);
        redemption.redeem(tokenIds);
    }

    function test__redeem__failure__revokedHash() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit the Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Revoke the Hash.
        redemption.revoke(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Redeeming the Hash after revoking should fail.
        vm.expectRevert(Redemption.UncommittedHash.selector);
        redemption.redeem(tokenIds);
    }

    function test__redeem__failure__redeemTwice() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Get some of the state prior to redemption.
        uint256 ownerBalanceBefore = owner.balance;
        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 totalCommitmentsBefore = redemption.totalCommitments();
        uint256 totalFundingBefore = redemption.totalFunding();

        // Redeem the Hash.
        redemption.redeem(tokenIds);

        // Ensure that the Hash was successfully redeemed for one ether.
        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
        assertEq(
            address(redemption).balance,
            redemptionBalanceBefore - 1 ether
        );

        // Ensure that the total commitments and funding haven't changed.
        assertEq(redemption.totalCommitments(), totalCommitmentsBefore);
        assertEq(redemption.totalFunding(), totalFundingBefore);

        // Ensure that the commitment was reset after redemption.
        assertEq(redemption.commitments(tokenIds[0]), address(0));

        // Ensure that the redemption contract still owns the Hash.
        assertEq(redemption.HASHES().ownerOf(tokenIds[0]), address(redemption));

        // Redeeming the Hash again should fail.
        vm.expectRevert(Redemption.UncommittedHash.selector);
        redemption.redeem(tokenIds);
    }

    function test__redeem__failure__emptyTokenIds() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Redeeming an empty array should fail due to dividing by zero if no
        // commitments were made.
        uint256[] memory tokenIds = new uint256[](0);
        vm.expectRevert();
        redemption.redeem(tokenIds);
    }

    function test__redeem__success__emptyTokenIds() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Get some of the state prior to redemption.
        uint256 ownerBalanceBefore = owner.balance;
        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 totalCommitmentsBefore = redemption.totalCommitments();
        uint256 totalFundingBefore = redemption.totalFunding();

        // Redeeming an empty array should succeed with no effect if
        // Hashes were committed.
        uint256[] memory tokenIds_ = new uint256[](0);
        redemption.redeem(tokenIds_);

        // Ensure that the ether balances of the owner and redemption contracts
        // haven't changed.
        assertEq(owner.balance, ownerBalanceBefore);
        assertEq(address(redemption).balance, redemptionBalanceBefore);

        // Ensure that the total commitments and funding haven't changed.
        assertEq(redemption.totalCommitments(), totalCommitmentsBefore);
        assertEq(redemption.totalFunding(), totalFundingBefore);
    }

    function test__redeem__success__singleTokenId() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit a Hash.
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 259;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Get some of the state prior to redemption.
        uint256 ownerBalanceBefore = owner.balance;
        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 totalCommitmentsBefore = redemption.totalCommitments();
        uint256 totalFundingBefore = redemption.totalFunding();

        // Redeem the Hash.
        redemption.redeem(tokenIds);

        // Ensure that the Hash was successfully redeemed for one ether.
        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
        assertEq(
            address(redemption).balance,
            redemptionBalanceBefore - 1 ether
        );

        // Ensure that the total commitments and funding haven't changed.
        assertEq(redemption.totalCommitments(), totalCommitmentsBefore);
        assertEq(redemption.totalFunding(), totalFundingBefore);

        // Ensure that the commitment was reset after redemption.
        assertEq(redemption.commitments(tokenIds[0]), address(0));

        // Ensure that the redemption contract still owns the Hash.
        assertEq(redemption.HASHES().ownerOf(tokenIds[0]), address(redemption));
    }

    function test__redeem__success__severalTokenIds() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit several Hashes.
        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Get some of the state prior to redemption.
        uint256 ownerBalanceBefore = owner.balance;
        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 totalCommitmentsBefore = redemption.totalCommitments();
        uint256 totalFundingBefore = redemption.totalFunding();

        // Redeeming the Hashes should succeed.
        redemption.redeem(tokenIds);

        // Ensure that the Hash was successfully redeemed for one ether per
        // redeemed Hash.
        assertEq(owner.balance, ownerBalanceBefore + tokenIds.length * 1 ether);
        assertEq(
            address(redemption).balance,
            redemptionBalanceBefore - tokenIds.length * 1 ether
        );

        // Ensure that the total commitments and funding haven't changed.
        assertEq(redemption.totalCommitments(), totalCommitmentsBefore);
        assertEq(redemption.totalFunding(), totalFundingBefore);

        // Ensure the state was updated correctly.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Ensure that the commitment was reset after redemption.
            assertEq(redemption.commitments(tokenIds[i]), address(0));

            // Ensure that the redemption contract still owns the Hash.
            assertEq(
                redemption.HASHES().ownerOf(tokenIds[i]),
                address(redemption)
            );
        }
    }

    function test__redeem__success__severalTokenIds__multipleRedemptions()
        external
    {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit several Hashes.
        uint256[] memory tokenIds = new uint256[](7);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        tokenIds[4] = 471;
        tokenIds[5] = 632;
        tokenIds[6] = 992;
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Get some of the state prior to redemption.
        uint256 ownerBalanceBefore = owner.balance;
        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 totalCommitmentsBefore = redemption.totalCommitments();
        uint256 totalFundingBefore = redemption.totalFunding();

        // Redeem several Hashes.
        uint256[] memory tokenIds_ = new uint256[](4);
        tokenIds_[0] = 259;
        tokenIds_[1] = 304;
        tokenIds_[2] = 322;
        tokenIds_[3] = 323;
        redemption.redeem(tokenIds_);

        // Ensure that the Hash was successfully redeemed for one ether per
        // redeemed Hash.
        assertEq(
            owner.balance,
            ownerBalanceBefore + tokenIds_.length * 1 ether
        );
        assertEq(
            address(redemption).balance,
            redemptionBalanceBefore - tokenIds_.length * 1 ether
        );

        // Ensure that the total commitments and funding haven't changed.
        assertEq(redemption.totalCommitments(), totalCommitmentsBefore);
        assertEq(redemption.totalFunding(), totalFundingBefore);

        // Ensure the state was updated correctly.
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            // Ensure that the commitment was reset after redemption.
            assertEq(redemption.commitments(tokenIds_[i]), address(0));

            // Ensure that the redemption contract still owns the Hash.
            assertEq(
                redemption.HASHES().ownerOf(tokenIds_[i]),
                address(redemption)
            );
        }

        // Get some of the state prior to redemption.
        ownerBalanceBefore = owner.balance;
        redemptionBalanceBefore = address(redemption).balance;
        totalCommitmentsBefore = redemption.totalCommitments();
        totalFundingBefore = redemption.totalFunding();

        // Revoke several more Hashes.
        uint256[] memory tokenIds__ = new uint256[](3);
        tokenIds__[0] = 471;
        tokenIds__[1] = 632;
        tokenIds__[2] = 992;
        redemption.redeem(tokenIds__);

        // Ensure that the Hash was successfully redeemed for one ether per
        // redeemed Hash.
        assertEq(
            owner.balance,
            ownerBalanceBefore + tokenIds__.length * 1 ether
        );
        assertEq(
            address(redemption).balance,
            redemptionBalanceBefore - tokenIds__.length * 1 ether
        );

        // Ensure that the total commitments and funding haven't changed.
        assertEq(redemption.totalCommitments(), totalCommitmentsBefore);
        assertEq(redemption.totalFunding(), totalFundingBefore);

        // Ensure the state was updated correctly.
        for (uint256 i = 0; i < tokenIds__.length; i++) {
            // Ensure that the commitment was reset after redemption.
            assertEq(redemption.commitments(tokenIds__[i]), address(0));

            // Ensure that the redemption contract still owns the Hash.
            assertEq(
                redemption.HASHES().ownerOf(tokenIds__[i]),
                address(redemption)
            );
        }
    }

    function test__redeem__success__commitRevokeCommit() external {
        // Fund the redemption contract with the full funding amount.
        fund(FUNDING_AMOUNT);

        // Impersonate the owner of a several DAO hashes that aren't DEX Labs
        // hashes and approve the redemption contract for all.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);

        // Commit several Hashes.
        uint256[] memory tokenIds = new uint256[](7);
        tokenIds[0] = 259;
        tokenIds[1] = 304;
        tokenIds[2] = 322;
        tokenIds[3] = 323;
        tokenIds[4] = 471;
        tokenIds[5] = 632;
        tokenIds[6] = 992;
        redemption.commit(tokenIds);

        // Revoke the Hashes.
        redemption.revoke(tokenIds);

        // Commit the Hashes again.
        redemption.commit(tokenIds);

        // Warp to the deadline.
        vm.warp(redemption.deadline());

        // Get some of the state prior to redemption.
        uint256 ownerBalanceBefore = owner.balance;
        uint256 redemptionBalanceBefore = address(redemption).balance;
        uint256 totalCommitmentsBefore = redemption.totalCommitments();
        uint256 totalFundingBefore = redemption.totalFunding();

        // Redeem the Hashes.
        redemption.redeem(tokenIds);

        // Ensure that the Hash was successfully redeemed for one ether per
        // redeemed Hash.
        assertEq(owner.balance, ownerBalanceBefore + tokenIds.length * 1 ether);
        assertEq(
            address(redemption).balance,
            redemptionBalanceBefore - tokenIds.length * 1 ether
        );

        // Ensure that the total commitments and funding haven't changed.
        assertEq(redemption.totalCommitments(), totalCommitmentsBefore);
        assertEq(redemption.totalFunding(), totalFundingBefore);

        // Ensure the state was updated correctly.
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Ensure that the commitment was reset after redemption.
            assertEq(redemption.commitments(tokenIds[i]), address(0));

            // Ensure that the redemption contract still owns the Hash.
            assertEq(
                redemption.HASHES().ownerOf(tokenIds[i]),
                address(redemption)
            );
        }
    }

    function test__redeem__success__manyRedemptionsForOneEther() external {
        // Fund the redemption contract with 10 ether.
        fund(10 ether);

        // Iterate through the first 8 Hashes that aren't DEX Labs hashes.
        // For each of these hashes that isn't deactivated, commit the hash.
        uint256 totalCommitments;
        IHashes hashes = redemption.HASHES();
        for (uint256 i = 100; i < 108; i++) {
            if (!hashes.deactivated(i)) {
                // Impersonate the owner of the Hash.
                vm.startPrank(hashes.ownerOf(i));
                hashes.setApprovalForAll(address(redemption), true);

                // Commit the Hash.
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = i;
                redemption.commit(tokenIds);

                // Increase the amount of commitments.
                totalCommitments += 1;
            }
        }

        // Ensure that the total amount of commitments is correct.
        assertEq(redemption.totalCommitments(), totalCommitments);

        // Warp to the a month after the deadline.
        vm.warp(redemption.deadline() + 30 days);

        // Get some state before redeeming the Hashes.
        uint256 redemptionEtherBalance = address(redemption).balance;

        // Iterate through the first 8 Hashes that aren't DEX Labs hashes.
        // For each of these hashes that was committed, redeem the hash. Since
        // less than or equal to 8 hashes were redeemed, each hash should
        // receive 1 ether.
        for (uint256 i = 100; i < 108; i++) {
            address committer = redemption.commitments(i);
            if (committer != address(0)) {
                // Impersonate the committer of the Hash.
                vm.startPrank(committer);

                // Get some state before redeeming the Hash.
                uint256 committerEtherBalance = committer.balance;

                // Redeem the Hash.
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = i;
                redemption.redeem(tokenIds);

                // Ensure that the owner received one ether for their Hash.
                assertEq(committer.balance, committerEtherBalance + 1 ether);

                // Ensure that the commitment was reset after redemption.
                assertEq(redemption.commitments(tokenIds[0]), address(0));

                // Ensure that the redemption contract still owns the Hash.
                assertEq(
                    redemption.HASHES().ownerOf(tokenIds[0]),
                    address(redemption)
                );
            }
        }

        // Ensure that the redemption contract's final balance is correct.
        assertEq(
            address(redemption).balance,
            redemptionEtherBalance - totalCommitments * 1 ether
        );
    }

    function test__redeem__success__manyRedemptionsForLessThanOneEther()
        external
    {
        // Fund the redemption contract with 10 ether.
        fund(10 ether);

        // Iterate through the first 25 Hashes that aren't DEX Labs hashes.
        // For each of these hashes that isn't deactivated, commit the hash.
        uint256 totalCommitments;
        IHashes hashes = redemption.HASHES();
        for (uint256 i = 100; i < 125; i++) {
            if (!hashes.deactivated(i)) {
                // Impersonate the owner of the Hash.
                vm.startPrank(hashes.ownerOf(i));
                hashes.setApprovalForAll(address(redemption), true);

                // Commit the Hash.
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = i;
                redemption.commit(tokenIds);

                // Increase the amount of commitments.
                totalCommitments += 1;
            }
        }

        // Commit several Hashes.
        address owner = address(0x4C71e905c48A80f235d2332A191be2c650e6a20C);
        vm.startPrank(owner);
        redemption.HASHES().setApprovalForAll(address(redemption), true);
        uint256[] memory tokenIds_ = new uint256[](7);
        tokenIds_[0] = 259;
        tokenIds_[1] = 304;
        tokenIds_[2] = 322;
        tokenIds_[3] = 323;
        tokenIds_[4] = 471;
        tokenIds_[5] = 632;
        tokenIds_[6] = 992;
        redemption.commit(tokenIds_);

        // Increase the amount of commitments.
        totalCommitments += tokenIds_.length;

        // Ensure that the total amount of commitments is correct.
        assertEq(redemption.totalCommitments(), totalCommitments);

        // Warp to the a month after the deadline.
        vm.warp(redemption.deadline() + 30 days);

        // Get some state before redeeming the Hashes.
        uint256 redemptionEtherBalance = address(redemption).balance;

        // Iterate through the first 25 Hashes that aren't DEX Labs hashes.
        // For each of these hashes that was committed, redeem the hash. Since
        // more than 549 hashes were redeemed, each hash should receive less
        // than 1 ether.
        uint256 totalFunding = redemption.totalFunding();
        for (uint256 i = 100; i < 125; i++) {
            address committer = redemption.commitments(i);
            if (committer != address(0)) {
                // Impersonate the committer of the Hash.
                vm.startPrank(committer);

                // Get some state before redeeming the Hash.
                uint256 committerEtherBalance = committer.balance;

                // Redeem the Hash.
                uint256[] memory tokenIds = new uint256[](1);
                tokenIds[0] = i;
                redemption.redeem(tokenIds);

                // Ensure that the owner received one ether for their Hash.
                assertEq(
                    committer.balance,
                    committerEtherBalance + totalFunding / totalCommitments
                );

                // Ensure that the commitment was reset after redemption.
                assertEq(redemption.commitments(tokenIds[0]), address(0));

                // Ensure that the redemption contract still owns the Hash.
                assertEq(
                    redemption.HASHES().ownerOf(tokenIds[0]),
                    address(redemption)
                );
            }
        }

        // Redeem multiple hashes simultaneously.
        uint256 ownerEtherBalance = owner.balance;
        vm.startPrank(owner);
        redemption.redeem(tokenIds_);
        assertEq(
            owner.balance,
            ownerEtherBalance +
                (totalFunding * tokenIds_.length) /
                totalCommitments
        );

        // Ensure that the redemption contract's final balance is correct.
        assertEq(
            address(redemption).balance,
            redemptionEtherBalance - totalFunding
        );
    }

    /// Draw Tests ///

    /// Reclaim Tests ///

    /// Helpers ///

    function fund(uint256 amount) internal {
        // Fund the redemption contract with the expected amount of ether.
        vm.startPrank(FUNDER);
        vm.deal(FUNDER, amount);
        (bool success, ) = address(redemption).call{value: amount}("");
        require(success, "couldn't fund the redemption contract");
    }
}
