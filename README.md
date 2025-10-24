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

### ✅ Challenge #2: Naive Receiver

**Vulnerability**: Multicall + Meta-transaction + Unauthorized flash loan

**Solution**: [test/naive-receiver/NaiveReceiver.t.sol](test/naive-receiver/NaiveReceiver.t.sol#L79-L120)

**Exploit**: This challenge combines three vulnerabilities:
1. **Unauthorized flash loans**: Anyone can force `FlashLoanReceiver` to take flash loans and pay fees by calling `pool.flashLoan(receiver, ...)`. The receiver doesn't verify the `initiator`, only checks if caller is the pool.
2. **Multicall with delegatecall**: The pool's `multicall()` uses `delegatecall`, which preserves `msg.sender` but changes `msg.data` to each individual call's data.
3. **Meta-transaction _msgSender()**: The `_msgSender()` function extracts the "real sender" from the last 20 bytes of `msg.data` when called via `trustedForwarder`.

By crafting a `withdraw()` call with the `deployer` address appended to the calldata and executing it through `BasicForwarder` → `multicall` → `delegatecall`, we can drain funds from `deposits[deployer]` without authorization.

**Attack Flow**:
1. Call 10 flash loans with 0 amount to drain receiver's 10 WETH in fees
2. Append `deployer` address to a `withdraw()` call's calldata
3. Execute via forwarder's meta-transaction to trigger multicall
4. In the delegatecall context, `_msgSender()` extracts `deployer` from calldata
5. Successfully withdraw all 1010 WETH to recovery address

**Key Takeaway**:
- Flash loan receivers must verify both the pool AND the initiator
- Combining `delegatecall` + meta-transactions that extract identity from `msg.data` is dangerous
- `delegatecall` preserves `msg.sender` but changes `msg.data`, breaking assumptions about calldata structure

---

## Running Solutions

Run all solutions:
```bash
forge test
```

Run a specific challenge:
```bash
forge test --match-test test_unstoppable -vvv
forge test --match-test test_naiveReceiver -vvv
```

## Progress

- [x] #1 - Unstoppable
- [x] #2 - Naive receiver
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
