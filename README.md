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

### ✅ Challenge #3: Truster

**Vulnerability**: Arbitrary external call in flash loan

**Solution**: [test/truster/Truster.t.sol](test/truster/Truster.t.sol)

**Exploit**: The `TrusterLenderPool.flashLoan` function allows calling any target address with arbitrary data. We exploit this by making the pool approve our attacker contract to spend all its tokens, then use `transferFrom` to drain the pool.

**Key Takeaway**: Never allow arbitrary external calls in privileged contexts. Whitelist allowed targets and validate call data.

---

### ✅ Challenge #4: Side Entrance

**Vulnerability**: Flash loan accounting bypass

**Solution**: [test/side-entrance/SideEntrance.t.sol](test/side-entrance/SideEntrance.t.sol)

**Exploit**: The pool's `flashLoan` function only checks if total ETH balance is restored, not how it was restored. We borrow ETH via flash loan, deposit it back through `deposit()` (which credits our internal balance), satisfy the balance check, then withdraw all ETH using our credited balance.

**Key Takeaway**: Flash loan repayment checks must distinguish between direct transfers and other ways funds can enter the contract. Internal accounting and actual balance must be properly separated.

---

### ✅ Challenge #5: The Rewarder

**Vulnerability**: Transfer-before-validation in batch processing

**Solution**: [test/the-rewarder/TheRewarder.t.sol](test/the-rewarder/TheRewarder.t.sol)

**Exploit**: The `claimRewards` function transfers tokens inside the loop (line 116) but only validates and updates the bitmap when token changes or at the end. By submitting multiple claims for the same token consecutively, each claim triggers a transfer but `_setClaimed` is called only once with the accumulated amount.

**Key Takeaway**: In batch processing, perform all validations and state updates before any external calls or transfers.

---

### ✅ Challenge #6: Selfie

**Vulnerability**: Flash loan governance attack

**Solution**: [test/selfie/Selfie.t.sol](test/selfie/Selfie.t.sol)

**Exploit**: The governance requires >50% voting power to queue actions. We use a flash loan to temporarily hold enough tokens, delegate voting power to ourselves, queue a governance action to call `emergencyExit(recovery)`, repay the loan, wait 2 days, then execute the action to drain the pool.

**Key Takeaway**: Governance systems should implement safeguards against flash loan attacks, such as snapshot-based voting, time-weighted voting power, or minimum holding periods.

---

### ✅ Challenge #7: Compromised

**Vulnerability**: Leaked oracle private keys

**Solution**: [test/compromised/Compromised.t.sol](test/compromised/Compromised.t.sol)

**Exploit**: The challenge provides hex-encoded strings that decode to private keys of two oracle sources (hex → base64 → private keys). We use these to manipulate the price oracle: set NFT price to 0, buy cheap, raise price to 999 ETH, sell high, restore price, and drain the exchange.

**Key Takeaway**: Oracle private keys must be kept secure. Use multi-signature schemes or decentralized oracle networks to prevent single points of failure.

---

### ✅ Challenge #8: Puppet

**Vulnerability**: Oracle manipulation via DEX price manipulation

**Solution**: [test/puppet/Puppet.t.sol](test/puppet/Puppet.t.sol)

**Exploit**: The lending pool uses Uniswap spot price as an oracle without safeguards. We dump all 1000 DVT tokens into the small Uniswap pool (10 ETH / 10 DVT), crashing the token price. This drastically reduces the collateral required to borrow. We then borrow all 100,000 DVT from the lending pool with our 25 ETH.

**Key Takeaway**: Never use spot prices from DEXs as oracles without protection. Use time-weighted average prices (TWAP), multiple oracle sources, or sufficient liquidity depth requirements.

---

### ✅ Challenge #9: Puppet V2

**Vulnerability**: Oracle manipulation via Uniswap V2 price manipulation

**Solution**: [test/puppet-v2/PuppetV2.t.sol](test/puppet-v2/PuppetV2.t.sol)

**Exploit**: Similar to Puppet V1 but using Uniswap V2. The lending pool uses Uniswap V2 spot price as an oracle. We swap all 10,000 DVT tokens for WETH in the pool (100 DVT / 10 WETH), crashing the DVT price. Then we convert our ETH to WETH and borrow all 1,000,000 DVT from the lending pool with the drastically reduced collateral requirement.

**Key Takeaway**: Same lesson as Puppet V1 - spot prices from any DEX version are manipulable. Always use time-weighted prices or multiple oracle sources.

---

### ✅ Challenge #11: Backdoor

**Vulnerability**: Malicious delegatecall during Safe wallet initialization

**Solution**: [test/backdoor/Backdoor.t.sol](test/backdoor/Backdoor.t.sol)

**Exploit**: The WalletRegistry creates Safe wallets for beneficiaries and sends them 10 tokens each. Safe's `setup` function allows a delegatecall during initialization. We exploit this by:
1. Creating an approval module contract
2. For each user, creating a Safe wallet with setup that delegatecalls our module
3. The module approves our attacker contract to spend tokens (executed in Safe's context via delegatecall)
4. After wallet creation and token distribution, immediately transferring tokens to recovery

**Key Takeaway**: Be extremely careful with delegatecalls during initialization. Validate or restrict the targets that can be called during setup.

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
forge test --match-test test_truster -vvv
forge test --match-test test_sideEntrance -vvv
forge test --match-test test_theRewarder -vvv
forge test --match-test test_selfie -vvv
forge test --match-test test_compromised -vvv
forge test --match-test test_puppet -vvv
forge test --match-test test_puppetV2 -vvv
forge test --match-test test_backdoor -vvv
```

## Progress

- [x] #1 - Unstoppable
- [x] #2 - Naive receiver
- [x] #3 - Truster
- [x] #4 - Side entrance
- [x] #5 - The rewarder
- [x] #6 - Selfie
- [x] #7 - Compromised
- [x] #8 - Puppet
- [x] #9 - Puppet V2
- [ ] #10 - Free rider
- [x] #11 - Backdoor
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
