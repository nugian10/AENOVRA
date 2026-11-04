// Deploy AenovraNFT to BNB Smart Chain.
//
// RUN BY THE OWNER ONLY, from their own machine/wallet:
//   1. Copy .env.example to .env and fill DEPLOYER_PRIVATE_KEY with the
//      My Wallet key (the OWNER wallet — never share it, never paste it
//      in chat). BSCSCAN_API_KEY is needed for source verification.
//   2. npx hardhat run scripts/deploy.js --network bsc
//   3. Verify the printed address + deckHash on BscScan, then activate
//      minting ONLY when the site + collection are ready:
//      setMintActive(true) from the owner wallet.
//
// The deployer pays gas from the owner wallet. The contract's owner
// is set to OWNER (My Wallet), revenue to AGENTIC (Binance Agentic
// Wallet) — the deployer address itself does not become owner unless
// it IS the owner wallet.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { ethers } = require("hardhat");

const OWNER = "0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097"; // My Wallet (owner)
const REVENUE = "0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7"; // Binance Agentic Wallet (revenue)
const AGENT_ID_REGISTRY = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F"; // SPACE ID .ai registry
const BASE_URI = "https://raw.githubusercontent.com/nugian10/AENOVRA/main/collection/metadata/";
const EXPECTED_DECK_HASH = "0xe83281f313b66ab004bb65d41ed51cf2de152aa9959031f95ce39acb36c74fa4";

async function main() {
  const deckJson = JSON.parse(
    fs.readFileSync(path.join(__dirname, "..", "..", "scripts", "deck.json"), "utf8")
  );
  const deck = ethers.getBytes("0x" + deckJson.deck.map((t) => t.toString(16).padStart(2, "0")).join(""));
  // The recorded deckHash is SHA-256 of the deck's COMPACT JSON encoding
  // (the generator's convention — NOT keccak256 of the raw bytes).
  const deckHash = "0x" + crypto.createHash("sha256")
    .update(JSON.stringify(deckJson.deck))
    .digest("hex");
  console.log("Deck length:", deck.length);
  console.log("Deck hash:  ", deckHash);
  if (deckHash.toLowerCase() !== EXPECTED_DECK_HASH.toLowerCase()) {
    throw new Error("DECK HASH MISMATCH — aborting deploy. Expected " + EXPECTED_DECK_HASH);
  }
  console.log("Deck hash matches expected value.");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Owner:   ", OWNER);
  console.log("Revenue: ", REVENUE);

  const Factory = await ethers.getContractFactory("AenovraNFT");
  const contract = await Factory.deploy(OWNER, REVENUE, AGENT_ID_REGISTRY, BASE_URI, deck);
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log("AenovraNFT deployed to:", address);
  console.log("name:", await contract.name(), "| symbol:", await contract.symbol());
  console.log("MAX_SUPPLY:", (await contract.MAX_SUPPLY()).toString());
  console.log("currentPrice:", ethers.formatEther(await contract.currentPrice()), "BNB");
  console.log("on-chain deckHash:", await contract.deckHash());
  console.log("mintActive:", await contract.mintActive());
  console.log("");
  console.log("Verify on BscScan with:");
  console.log("  npx hardhat verify --network bsc", address,
    OWNER, REVENUE, AGENT_ID_REGISTRY, BASE_URI,
    '"0x' + Buffer.from(deck).toString("hex") + '"');
  console.log("");
  console.log("NEXT: do NOT activate minting until the collection is live on GitHub");
  console.log("and the site points at this contract. Activate with setMintActive(true)");
  console.log("from the OWNER wallet only.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
