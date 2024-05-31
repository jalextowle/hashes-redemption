## Hashes Redemption

This repository implements a redemption contract for the HashesDAO according to the specification outlined in the [Alternate proposal to Permutation 9](https://snapshot.org/#/thehashes.eth/proposal/0xde5e43416c13746e22ba1c86dde021098131405b626ca0bea412809fed39e0a5).

This contract has been deployed to Etherscan and verfied at [0xcd197d494f049ab1b8a3f135fabf04f8a73e5db1](https://etherscan.io/address/0xcd197d494f049ab1b8a3f135fabf04f8a73e5db1).

## Usage

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
