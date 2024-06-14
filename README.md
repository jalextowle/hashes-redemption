# Hashes Redemption

This README will help walk you through the process of redeeming a Hash (a Hashes NFT) using the [Hashes Redemption contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac). This contract has been deployed to Ethereum Mainnet and verified on Etherscan. For more context relating to this contract, see [the Hashes Redemption proposal](https://vote.thehashes.xyz/). Prior to reading this README and using the Hashes Redemption contract, please refer to the [disclaimer](#Disclaimer). Let's dive in!

## What is the Hashes Redemption?

As the [proposal](https://vote.thehashes.xyz/) outlines, all of the ETH and WETH previously owned by the HashesDAO (542.992 ETH total) was sent to the Hashes Redemption contract. This ETH can be claimed by owners of DAO Hashes that choose to redeem their Hashes using the [Hashes Redemption Contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac). If all of the 818 eligible DAO Hashes are redeemed, each redeemer will receive 0.66 ETH. If less than 543 Hashes owners redeem their Hashes, each redeemer will receive 1 ETH. DEX Labs Hashes, deactivated DAO Hashes, non-DAO Hashes, and Hashes purchased by the HashesDAO are all ineligible for redemption.

## How will redemption work?


Hashes owners have until the 5:45 PM GMT on Monday, July 8th, 2024 deadline, to redeem their Hashes. All committed Hashes by this time will be redeemed; uncommitted Hashes will not. Redeeming your Hash is a personal decision and means forfeiting ownership of your NFT and any claims to the Hashes collection NFTs.

To redeem your Hash, follow this two-step process:
1. **Commit**: Use the commit function before the deadline. You can revoke your commitment before the deadline if you change your mind using the revoke function.
2. **Redeem**: After the deadline, use the redeem function to finalize the redemption.

Ensure you commit your Hash from a wallet that can receive ether (e.g., Metamask or Hardware wallet).

## How can I commit my Hash for redemption?

If the deadline hasn't passed, and you have an eligible Hash that hasn't been committed, you can commit your Hash for redemption. Committing your Hash transfers it to the Hashes Redemption contract, enabling redemption post-deadline. If you change your mind, revoke your commitment before the deadline. The address you commit with must be the same as the one you redeem with - ensure your commitment address can receive ether since using an address that cannot receive ether will render your reward inaccessible.

To commit your Hash, follow these steps:
1. **Set Approval**: Approve the Hashes Redemption contract on the [Hashes NFT contract](https://etherscan.io/address/0xD07e72b00431af84AD438CA995Fd9a7F0207542d) via Etherscan.
    * For a single Hash or maximum control, use the `approve` function with the `to` parameter set to the [Hashes Redemption address](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac) and the `tokenId` parameter set to your Hash's token ID.
    * For multiple Hashes, use the `setApprovalForAll` function with the `operator` parameter set to the [Hashes Redemption address](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac) and the `approved` parameter set to true.
2. **Commit Hashes**: Once approved, `commit` your Hashes using the commit function on the [Hashes Redemption contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac). This function takes a list of Hashes token IDs, allowing you to commit multiple Hashes at once. Ensure the token IDs are in ascending order (e.g., `[1, 2, 50, 100]`) without duplicates. If committing a single Hash, the list will contain only that Hash's token ID (e.g., `[2]`).

Following these steps ensures your Hashes are correctly committed for redemption.

## How can I revoke my commitment to redeem my Hash?

If the deadline hasn't been reached and you have already committed a Hash to the [Hashes Redemption contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac), you can revoke your commitment to redeem your Hash. Revoking your commitment to redeem your Hash will transfer the Hash back to your wallet and will revoke your ability to redeem the Hash after the deadline. If you change your mind, you can re-commit your Hash before the deadline.

You can revoke your commitment to redeem your Hashes using the `revoke` function on the [Hashes Redemption contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac). This function takes in a list of Hashes token IDs, which allows you to revoke all of your commitments at once. To ensure that you successfully revoke your commitments, make sure that your token IDs are listed in ascending order (ex. `[1, 2, 50, 100]` is ascending) without duplicating any Hashes IDs. If you are only revoking one Hash, the only entry in the list will be the token ID of your Hash.

## How can I redeem my Hash?

If the deadline has been reached and you have already committed a Hash to the [Hashes Redemption contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac), you can redeem your Hash to collect your portion of the ether that was collected by the [Hashes Redemption contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac). Redeeming your Hash will send the proceeds of your redemption to your wallet.

You can redeem your Hashes using the `redeem` function on the [Hashes Redemption contract](https://etherscan.io/address/0x73d0a9c38932e08ec84091c6967fdd2527d5a3ac). This function takes in a list of Hashes token IDs, which allows you to redeem all of your Hashes at once. To ensure that you successfully redeem your Hashes, make sure that your token IDs are listed in ascending order (ex. `[1, 2, 50, 100]` is ascending) without duplicating any Hashes IDs. If you are only redeeming one Hash, the only entry in the list will be the token ID of your Hash.

## FAQ

- How do I find my token ID?
    - You can find this by looking up your NFT on OpenSea. For example, the token ID of [this NFT](https://opensea.io/assets/ethereum/0xd07e72b00431af84ad438ca995fd9a7f0207542d/455) is #455.
- I can't receive ether at my address. Can I still redeem my Hash?
    - Yes, you can still redeem your Hash, but you will need to transfer it to another address that can receive ether in order to claim your redemption reward.

## Developers

This repository uses foundry to compile the code and run tests: https://github.com/foundry-rs/foundry.

### Build

```shell
$ forge build
```

### Test

Since we use mainnet fork testing, you'll need to fill out the `.env_template`
and copy it to `.env` in order to run the tests.

```shell
$ forge test
```

## Disclaimer

This README is intended for informational purposes only and should not be construed as financial, investment, or legal advice. The decision to redeem a Hash using the Hashes Redemption contract is a personal choice that should be made based on your own research, risk tolerance, and understanding of the potential consequences.

By providing this README and the Hashes Redemption contract, I am not encouraging or advising anyone to use the Hashes Redemption contract. The choice to interact with this contract is yours alone, and you assume full responsibility for any risks or losses that may result from your decision.

Please be aware that interacting with any smart contract carries inherent risks, including but not limited to the potential for smart contract vulnerabilities, unexpected contract behavior, and the irreversible nature of blockchain transactions. Thoroughly assess your risk tolerance and make sure you fully understand how the Hashes Redemption contract works before choosing to commit to or redeem a Hash.
