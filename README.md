# Damn Vulnerable DeFi - Solutions

This repository contains my solutions to the [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) challenges.

## About Damn Vulnerable DeFi

Damn Vulnerable DeFi is a smart contract security playground for developers, security researchers and educators. It features a collection of vulnerable Solidity smart contracts covering flashloans, price oracles, governance, NFTs, DEXs, lending pools, smart contract wallets, timelocks, vaults, meta-transactions, token distributions, upgradeability and more.

## Setup

1. Clone this repository
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. Rename `.env.sample` to `.env` and add a valid RPC URL (needed for mainnet fork challenges)
4. Run `forge build` to compile contracts
5. Run `forge test` to verify all solutions

## Solutions

### ✅ Challenge #1: Unstoppable

**Vulnerability**: ERC4626 accounting mismatch

**Solution**: [test/unstoppable/Unstoppable.t.sol](test/unstoppable/Unstoppable.t.sol#L93-L98)

**Exploit**: Directly transfer tokens to the vault bypassing the `deposit()` function. This breaks the invariant that `convertToShares(totalSupply) == totalAssets()`, causing all flash loan attempts to revert with `InvalidBalance()`.

**Key Takeaway**: Never assume tokens can only enter a contract through your designated functions. ERC20 `transfer()` can send tokens directly to any address, potentially breaking internal accounting logic.

---

## Running Solutions

Run all solutions:
```bash
forge test
```

Run a specific challenge:
```bash
forge test --match-test test_unstoppable -vvv
```

## Progress

- [x] #1 - Unstoppable
- [ ] #2 - Naive receiver
- [ ] #3 - Truster
- [ ] #4 - Side entrance
- [ ] #5 - The rewarder
- [ ] #6 - Selfie
- [ ] #7 - Compromised
- [ ] #8 - Puppet
- [ ] #9 - Puppet V2
- [ ] #10 - Free rider
- [ ] #11 - Backdoor
- [ ] #12 - Climber
- [ ] #13 - Wallet mining
- [ ] #14 - Puppet V3
- [ ] #15 - ABI smuggling
- [ ] #16 - Shards

## Resources

- [Official Challenges](https://www.damnvulnerabledefi.xyz/)
- [Original Repository](https://github.com/theredguild/damn-vulnerable-defi)
- [Foundry Book](https://book.getfoundry.sh/)

## Disclaimer

All code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

DO NOT USE IN PRODUCTION.
