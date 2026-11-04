# AenovraNFT — Smart Contract

ERC-721, BNB Smart Chain Mainnet (chain ID 56). Modelled on the proven
OOBIX v2 / MythRealm v2 pattern (WEDO model).

## Spec (confirmed by Nugraha, 4 Nov 2026)

| Item | Value |
|---|---|
| Name / symbol | Aenovra / AENO |
| MAX_SUPPLY | 5,555 (token IDs 1–5,555, sequential) |
| Price | Flat **0.0003 BNB** for every token (`currentPrice()`) |
| mint() | No arguments, 1 token per call, exact payment only |
| Agent gate | SPACE ID Agent ID, registry `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (owner can disable) |
| NoContracts | Calls from contracts revert |
| Max per wallet | **10**, enforced on-chain |
| Rarity | Common 3333 / Uncommon 1333 / Rare 555 / Epic 250 / Legendary 84 |
| deckHash | `0xe83281f313b66ab004bb65d41ed51cf2de152aa9959031f95ce39acb36c74fa4` |
| Payment | Forwarded directly to revenue wallet inside `mint()` — contract balance stays 0 |
| Owner | My Wallet `0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097` |
| Revenue | Binance Agentic Wallet `0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7` |
| baseURI | `https://raw.githubusercontent.com/nugian10/AENOVRA/main/collection/metadata/` |
| mintActive | Default `false`; only the owner can activate |

## deckHash convention — read this

The recorded deckHash is **SHA-256 of the deck's compact JSON encoding**
(`"[0,0,1,2,...]"`), as computed by the deck generator
(`art/generate.py`). It is **NOT** keccak256 of the raw deck bytes —
that would be a different value (`0xf38b70e3…`).

`deckHash()` on-chain rebuilds that exact JSON encoding from the stored
deck and returns its SHA-256, so the on-chain value equals the recorded
one exactly. Verified off-chain and on-chain in the test suite.
Anyone can re-check it with:
`sha256(json.dumps(deck, separators=(",", ":")).encode())`.

## Files

- `contracts/AenovraNFT.sol` — the contract
- `contracts/mocks/MockAgentIdNFT.sol` — test-only mock registry + mock contract caller
- `test/AenovraNFT.test.js` — 18 tests (see below)
- `scripts/deploy.js` — mainnet deploy script (owner runs it)
- `hardhat.config.js` — Solidity 0.8.24, optimizer runs 200, cancun, BSC + BSC testnet

## Tests

```bash
npx hardhat test   # 18 passing
```

Covered: deployment values, deckHash exact match (off-chain + on-chain),
rarityOf vs deck.json, wrong-deck rejection, Agent ID gate pass/fail,
NoContracts, mint inactive, exact-payment enforcement, mint #1
(rarity, seed, tokenURI, payment forwarded, contract balance 0),
max 10 per wallet, gate disable by owner, owner-only admin,
price change locked after first mint, withdraw safety valve.

Runtime size: 9,494 bytes (limit 24,576). No audit — BscScan source
verification is not an audit.

## Deploy (owner only — needs the My Wallet signature)

Muse cannot sign or deploy. The owner deploys from their own machine:

```bash
cd ~/workspace/projects/aenovra/contract
cp .env.example .env
# Fill .env: DEPLOYER_PRIVATE_KEY = My Wallet key (never share/paste it),
#            BSCSCAN_API_KEY = BscScan API key (for verification)
npx hardhat run scripts/deploy.js --network bsc
```

The script aborts if the deck hash does not match the expected value.
It prints the deployed address and the exact `hardhat verify` command.

Constructor args (in order):
1. `0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097` (initialOwner = My Wallet)
2. `0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7` (revenueWallet = Agentic Wallet)
3. `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (agentIdRegistry)
4. `"https://raw.githubusercontent.com/nugian10/AENOVRA/main/collection/metadata/"` (baseURI)
5. deck bytes from `../scripts/deck.json` (5,555 bytes — the script builds them)

## After deploy (owner only)

1. Verify source on BscScan with the printed command.
2. Check on-chain: `name()` = Aenovra, `symbol()` = AENO,
   `deckHash()` = `0xe83281f3…74fa4`, `currentPrice()` = 0.0003 BNB,
   `owner()` = My Wallet, `revenueWallet()` = Agentic Wallet.
3. Confirm the collection is live on GitHub first
   (`collection/metadata/1.json` reachable), then activate minting:
   `setMintActive(true)` from the owner wallet.
4. Update the site to point at the deployed contract address.
