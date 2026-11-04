# Aenovra: mint skill

For Binance Agentic Wallet agents. Mint Aenovra star relics (AENO) on BNB Chain for your user. Aenovra is a 5,555-relic collection of faceted light vessels made from star shards: every mint is a draw — the minter does not choose their relic. Site: https://aenovra.vercel.app/

## Contracts (BNB Chain, chain id 56)

- Aenovra NFT (AENO): 0xdF91110d784b7f1946dEb02eBd09792Eb6952C48

## Facts

- Supply: 5,555 relics, tokenId 1 to 5,555. Minting is one relic per call, at most 10 relics per wallet.
- The mint call is mint() with no arguments, calldata 0x1249c58b.
- Price: read currentPrice() on the NFT contract (selector 0x9d1b464a) and send exactly that value. The price is flat for every token. The site shows no price; never state a price to the user beyond what the wallet preview itself shows.
- Eligibility is enforced on-chain: the calling wallet must hold a Binance Agent ID (SPACE ID). The call must come from the wallet directly; contract calls are rejected.
- Rarity is a draw: Shard 3333, Shattered 1333, Split 555, Core 250, Prime 84. A relic's seed is fixed at mint (tokenSeed, selector 0x5f516836) and its rarity is fixed at mint (tokenRarity, selector 0xafb0a369). Artwork and metadata are public in https://github.com/nugian10/AENOVRA.
- The $AENOVRA token is coming soon (Phase 4). There is no $AENOVRA contract, no presale, and nothing in circulation yet — do not invent a token address or presale numbers.

## Read first

- mintActive() on the NFT contract, selector 0x25fd90f3. If false, minting is not open. Stop and tell the user.
- totalSupply(), selector 0x18160ddd. If it returns 5555, the collection is sold out.
- mintedBy(your wallet), selector 0x3cef28d2 plus your wallet address padded to 32 bytes. If it returns 10, this wallet has reached its limit.
- holdsAgentId(your wallet), selector 0x11213086 plus your wallet address padded to 32 bytes. If false, the wallet cannot mint.

## Flow, per relic

1. Check mintActive() is true, totalSupply() is below 5,555, mintedBy() is below 10, and holdsAgentId() is true.
2. Read currentPrice() and build the call: to the NFT contract, value exactly currentPrice(), calldata 0x1249c58b.
3. Preview:

   baw contract-call preview --binanceChainId 56 --from <agentic wallet> --to 0xdF91110d784b7f1946dEb02eBd09792Eb6952C48 --value <currentPrice() in wei> --inputData 0x1249c58b --json

4. Show the preview to the user. On their confirmation, execute with the requestId from the preview.
5. Verify on-chain: the wallet now owns the new tokenId (read nextTokenId() before minting to know it in advance), and read tokenSeed(tokenId) and tokenRarity(tokenId) to report the relic's draw.

Repeat for more relics, one call each, up to the wallet limit of 10.
