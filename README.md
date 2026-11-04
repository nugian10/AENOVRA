# AENOVRA — Relic NFT Collection

5,555 faceted star-shard relic vessels on BNB Chain (56).
Each token is ONE artifact: a vessel of light, cracked like a
fingerprint — no two relics alike. Not a creature, not an animal,
not a stone tablet.

## Specs

- Supply: 5,555, token IDs 1..5555
- Chain: BNB Smart Chain (56), ERC-721 (contract NOT deployed yet)
- Mint: agent-only, max 10 per wallet (contract spec — the price
  never appears in artwork or metadata)
- Art: flat screen-print SVG, 900×1125, sharp angles, palette
  black / bone / orange / deep purple. No text, no gradients, no 3D.
- Storage: UNDECIDED. Metadata `image` uses the placeholder
  `ipfs://<IMAGES_CID>/N.svg` until storage is chosen.

## Traits

| Trait | Values |
|---|---|
| Vessel Form | Monolith, Shard Vessel, Orb Cage, Chalice, Prism, Ringed Vessel, Twin Spires, Hex Vessel |
| Material | Obsidian, Star Glass, Bone Ceramic, Violet Crystal, Ember Bronze, Void Iron |
| Core | Ember, Violet Flame, Bone Light, Solar Gold, Amethyst, Pale Star |
| Crack Pattern | Single Rift, Spiderweb, Lightning Fork, Ring Fracture, Cross Rift, Hairline Web |
| Orbit | Single Ring, Double Ring, Tilted Ring, Broken Arc, Twin Rings, None |
| Background | Void Black, Deep Purple, Bone, Ember Dusk, Violet Night, Charcoal |
| Rarity | Common 3333, Uncommon 1333, Rare 555, Epic 250, Legendary 84 |

Rarity comes from `scripts/deck.json` (deterministic shuffle),
not from random rolls. Legendary relics always have an orbit and
a larger core.

## Generator (OOBIX pattern)

- `art/generate.py` — deterministic generator. Seed per token:
  `seed = ((token_id * 2654435761) ^ 0x41454E4F) & 0xFFFFFFFF`
  with salt "AENO", mulberry32 PRNG, fixed trait draw order.
  Re-running regenerates byte-identical files.
- `art/verify.py` — full verification (counts, hashes, rarity,
  JSON/XML validity, no text/gradient/price/URL in the collection).
- `scripts/deck.json` — rarity deck + deckHash.

## Usage

```bash
python3 art/generate.py              # regenerate the full collection
python3 art/generate.py --only 1,2,3 --out /tmp/preview   # preview SVGs
python3 art/verify.py                # verify everything
```

Local only: no deploy, no upload, no pin, no network, no spend.
