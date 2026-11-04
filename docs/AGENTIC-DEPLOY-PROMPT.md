# Aenovra v1 — Deploy prompt for the Binance Agent (Agentic Wallet)

> ⚠️ **NOT DEPLOYED YET — DEPLOY EXACTLY ONCE.**
> Aenovra v1 has never been deployed. Deploy it **once** to Mainnet and
> never again. A second deploy would create a useless duplicate contract
> with a different address that the site will not use.
> After deploy, mint stays **OFF** (`mintActive` false) until the owner
> activates it separately at launch.

## Task

Deploy the AenovraNFT **v1** contract to **BNB Smart Chain MAINNET (chainId 56) only**.
No testnet. Do not deploy twice.

## Sources

Public repo: https://github.com/nugian10/AENOVRA (branch main).
Hardhat project: `contract/` in the repo root.
Contract: `contract/contracts/AenovraNFT.sol` (Aenovra / AENO, Solidity 0.8.24, OpenZeppelin 5.4.0).
Deck: `scripts/deck.json` in the repo root — do NOT regenerate the deck; use this file as-is.
Deploy script: `contract/scripts/deploy.js` — run from the `contract/` folder:
`npx hardhat run scripts/deploy.js --network bsc`.
Before deploy, run `npx hardhat test` from the `contract/` folder — all 18 tests must pass.

> Pre-flight check: if `contract/contracts/AenovraNFT.sol` or
> `scripts/deck.json` is missing from the repo, STOP. Do not deploy from
> any other source. Report back that the contract folder has not been
> pushed yet.

## Constructor arguments (in this order, do not change)

1. `initialOwner` (contract owner): `0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097` — Nugraha's My Wallet.
   The owner is My Wallet, NOT the Agentic Wallet (same as Mythora, MythRealm, MINTFORM, XOVRATH).
2. `revenueWallet_` (mint revenue recipient): `0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7` — Binance Agentic Wallet.
   Mint payments are forwarded DIRECTLY to this address inside `mint()` (they never sit in the contract first).
3. `agentIdRegistry_`: `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` — SPACE ID .ai Agent ID NFT.
4. `baseURI_`: `https://raw.githubusercontent.com/nugian10/AENOVRA/main/collection/metadata/`
5. `deck_`: contents of `scripts/deck.json` (5,555 bytes; deckHash `0xe83281f313b66ab004bb65d41ed51cf2de152aa9959031f95ce39acb36c74fa4`,
   counts Common 3333 / Uncommon 1333 / Rare 555 / Epic 250 / Legendary 84).

Note on the deck hash: the recorded deckHash is **SHA-256 of the deck's compact JSON encoding**
(`"[0,0,1,2,...]"`), as computed by the deck generator. It is NOT keccak256 of the raw deck bytes
(that would be a different value). The contract's `deckHash()` rebuilds that exact JSON encoding
on-chain and returns its SHA-256. The deploy script aborts if the hash does not match.

## Gas

Deploy at **0.05 gwei**. Measured deploy cost on a local Hardhat network: 7,642,777 gas =
**~0.0003821 BNB** (~Rp 4,900). The deployer wallet (Agentic Wallet) must hold at least
~0.002 BNB before deploying. Do not deploy above 1 gwei without the owner's confirmation.

## After deploy — read back and report

Read back from the contract and report all of it:
- contract address + deploy tx hash + BscScan link
- `owner()` = `0x0262...` (My Wallet)
- `revenueWallet()` = `0x89c3...` (Agentic Wallet)
- `agentIdRegistry()` = `0x60B9...`
- `baseURI()` = the GitHub URL above
- `totalSupply()` = 0, `mintActive()` = false, `currentPrice()` = 0.0003 BNB
- `MAX_SUPPLY` = 5555, `deckHash()` = `0xe832...`
- `hasAgentId(0x89c3...)` = true

**Mint STAYS OFF after deploy** (`mintActive` false). Do not turn mint on.
Do not call `setMintActive(true)` — that happens only at launch, by the owner.

## If the agent login / connection fails

This Binance agent connection failed at the first step before, on 29 Oct 2026
("Pertama juga sudah tidak bisa"), cause unknown. If login fails again, the fix
is re-pairing / logging in again in the Binance app — not changing the contract.
Do not change any address, deck, or price to "fix" the connection.

## What is NOT allowed

- Never ask anyone for a seed phrase, private key, or pairing code.
- Do not deploy to testnet, do not deploy twice, do not change the price
  (flat 0.0003 BNB) or the deck.
- This contract has NOT been independently audited — do not claim it has been audited.
