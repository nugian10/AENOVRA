const { expect } = require("chai");
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

const OWNER = "0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097";
const REVENUE = "0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7";
const REGISTRY = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F";
const BASE_URI = "https://raw.githubusercontent.com/nugian10/AENOVRA/main/collection/metadata/";
const EXPECTED_DECK_HASH = "0xe83281f313b66ab004bb65d41ed51cf2de152aa9959031f95ce39acb36c74fa4";
const PRICE = ethers.parseEther("0.0003");

const deckJson = JSON.parse(
  fs.readFileSync(path.join(__dirname, "..", "..", "scripts", "deck.json"), "utf8")
);
const deckBytes = ethers.getBytes(
  "0x" + deckJson.deck.map((t) => t.toString(16).padStart(2, "0")).join("")
);

describe("AenovraNFT", function () {
  let aenovra, registry, caller, owner, revenue, minter, stranger;
  let ownerSigner;

  async function deploy() {
    [ownerSigner, minter, stranger] = await ethers.getSigners();
    // Tests run as Hardhat signers; the CONTRACT owner/revenue are the
    // real addresses (no funds there), so owner-only calls are made by
    // impersonating the owner address.
    await ethers.provider.send("hardhat_setBalance", [
      OWNER,
      "0x8AC7230489E80000", // 10 ETH
    ]);
    owner = await ethers.getImpersonatedSigner(OWNER);

    const Registry = await ethers.getContractFactory("MockAgentIdNFT");
    registry = await Registry.deploy();
    await registry.waitForDeployment();

    const Caller = await ethers.getContractFactory("MockCaller");
    caller = await Caller.deploy();
    await caller.waitForDeployment();

    const Factory = await ethers.getContractFactory("AenovraNFT");
    aenovra = await Factory.deploy(OWNER, REVENUE, await registry.getAddress(), BASE_URI, deckBytes);
    await aenovra.waitForDeployment();

    // Give the minter an Agent ID in the mock registry.
    await registry.mintTo(minter.address);
  }

  beforeEach(deploy);

  describe("deployment", function () {
    it("has the right name, symbol, supply and price", async function () {
      expect(await aenovra.name()).to.equal("Aenovra");
      expect(await aenovra.symbol()).to.equal("AENO");
      expect(await aenovra.MAX_SUPPLY()).to.equal(5555);
      expect(await aenovra.MAX_PER_WALLET()).to.equal(10);
      expect(await aenovra.MINT_PRICE()).to.equal(PRICE);
      expect(await aenovra.mintPrice()).to.equal(PRICE);
      expect(await aenovra.currentPrice()).to.equal(PRICE);
      expect(await aenovra.getMintPrice()).to.equal(PRICE);
    });

    it("has the right owner, revenue, registry, baseURI, mintActive=false", async function () {
      expect(await aenovra.owner()).to.equal(OWNER);
      expect(await aenovra.revenueWallet()).to.equal(REVENUE);
      expect(await aenovra.agentIdRegistry()).to.equal(await registry.getAddress());
      expect(await aenovra.baseURI()).to.equal(BASE_URI);
      expect(await aenovra.mintActive()).to.equal(false);
      expect(await aenovra.mintOpen()).to.equal(false);
      expect(await aenovra.agentIdCheckRequired()).to.equal(true);
      expect(await aenovra.totalSupply()).to.equal(0);
      expect(await aenovra.totalMinted()).to.equal(0);
      expect(await aenovra.nextTokenId()).to.equal(1);
    });

    it("deckHash matches the committed deck exactly", async function () {
      // Off-chain: the recorded hash is SHA-256 of the compact JSON
      // encoding (the generator's convention).
      const crypto = require("crypto");
      const offChain = "0x" + crypto.createHash("sha256")
        .update(JSON.stringify(deckJson.deck))
        .digest("hex");
      expect(offChain).to.equal(EXPECTED_DECK_HASH);
      // On-chain: deckHash() rebuilds that same encoding and hashes it.
      expect(await aenovra.deckHash()).to.equal(EXPECTED_DECK_HASH);
    });

    it("rarityOf matches deck.json for sampled token IDs", async function () {
      for (const id of [1, 2, 100, 1000, 3000, 5555]) {
        expect(await aenovra.rarityOf(id)).to.equal(deckJson.deck[id - 1]);
      }
      await expect(aenovra.rarityOf(0)).to.be.revertedWithCustomError(aenovra, "ExceedsMaxSupply");
      await expect(aenovra.rarityOf(5556)).to.be.revertedWithCustomError(aenovra, "ExceedsMaxSupply");
    });

    it("reverts on a wrong deck (bad counts)", async function () {
      const bad = new Uint8Array(5555).fill(0);
      const Factory = await ethers.getContractFactory("AenovraNFT");
      await expect(
        Factory.deploy(OWNER, REVENUE, await registry.getAddress(), BASE_URI, bad)
      ).to.be.revertedWithCustomError(Factory, "InvalidDeck");
    });

    it("reverts on a zero owner / revenue / registry", async function () {
      const Factory = await ethers.getContractFactory("AenovraNFT");
      // Zero owner is caught first by OpenZeppelin Ownable.
      await expect(
        Factory.deploy(ethers.ZeroAddress, REVENUE, await registry.getAddress(), BASE_URI, deckBytes)
      ).to.be.revertedWithCustomError(Factory, "OwnableInvalidOwner");
      await expect(
        Factory.deploy(OWNER, ethers.ZeroAddress, await registry.getAddress(), BASE_URI, deckBytes)
      ).to.be.revertedWithCustomError(Factory, "InvalidAddress");
      await expect(
        Factory.deploy(OWNER, REVENUE, ethers.ZeroAddress, BASE_URI, deckBytes)
      ).to.be.revertedWithCustomError(Factory, "InvalidAddress");
    });
  });

  describe("agent ID gate", function () {
    it("holdsAgentId / hasAgentId reflect the registry", async function () {
      expect(await aenovra.holdsAgentId(minter.address)).to.equal(true);
      expect(await aenovra.hasAgentId(minter.address)).to.equal(true);
      expect(await aenovra.holdsAgentId(stranger.address)).to.equal(false);
    });

    it("reverts NoAgentId for a wallet without an Agent ID", async function () {
      await aenovra.connect(owner).setMintActive(true);
      await expect(
        aenovra.connect(stranger).mint({ value: PRICE })
      ).to.be.revertedWithCustomError(aenovra, "NoAgentId");
    });
  });

  describe("minting", function () {
    beforeEach(async function () {
      await aenovra.connect(owner).setMintActive(true);
    });

    it("reverts MintInactive when mint is off", async function () {
      await aenovra.connect(owner).setMintActive(false);
      await expect(
        aenovra.connect(minter).mint({ value: PRICE })
      ).to.be.revertedWithCustomError(aenovra, "MintInactive");
    });

    it("reverts NoContracts for calls from a contract", async function () {
      await expect(
        caller.tryMint(await aenovra.getAddress(), { value: PRICE })
      ).to.not.be.reverted; // the call itself succeeds, inner mint fails
      const ok = await caller.tryMint.staticCall(await aenovra.getAddress(), { value: PRICE });
      expect(ok).to.equal(false);
      expect(await aenovra.totalSupply()).to.equal(0);
    });

    it("reverts IncorrectPayment on under- and overpayment", async function () {
      await expect(
        aenovra.connect(minter).mint({ value: PRICE - 1n })
      ).to.be.revertedWithCustomError(aenovra, "IncorrectPayment");
      await expect(
        aenovra.connect(minter).mint({ value: PRICE + 1n })
      ).to.be.revertedWithCustomError(aenovra, "IncorrectPayment");
      await expect(
        aenovra.connect(minter).mint({ value: 0 })
      ).to.be.revertedWithCustomError(aenovra, "IncorrectPayment");
    });

    it("mints token #1 with the deck rarity, seed, tokenURI and payment forwarded", async function () {
      const revenueBefore = await ethers.provider.getBalance(REVENUE);
      const tx = await aenovra.connect(minter).mint({ value: PRICE });
      const receipt = await tx.wait();

      expect(await aenovra.totalSupply()).to.equal(1);
      expect(await aenovra.ownerOf(1)).to.equal(minter.address);
      expect(await aenovra.tokenRarity(1)).to.equal(deckJson.deck[0]);
      expect(await aenovra.tokenSeed(1)).to.not.equal(ethers.ZeroHash);
      expect(await aenovra.tokenURI(1)).to.equal(BASE_URI + "1.json");
      expect(await aenovra.mintedBy(minter.address)).to.equal(1);
      // Payment forwarded directly: contract holds nothing, revenue got it.
      expect(await ethers.provider.getBalance(await aenovra.getAddress())).to.equal(0);
      expect(await ethers.provider.getBalance(REVENUE)).to.equal(revenueBefore + PRICE);

      // Minted event carries minter, tokenId, price, rarity, seed.
      const ev = receipt.logs.find((l) => {
        try {
          return aenovra.interface.parseLog(l).name === "Minted";
        } catch {
          return false;
        }
      });
      const parsed = aenovra.interface.parseLog(ev);
      expect(parsed.args.minter).to.equal(minter.address);
      expect(parsed.args.tokenId).to.equal(1);
      expect(parsed.args.price).to.equal(PRICE);
      expect(parsed.args.rarity).to.equal(deckJson.deck[0]);
    });

    it("tokenURI reverts for an unminted token", async function () {
      await expect(aenovra.tokenURI(1)).to.be.revertedWithCustomError(
        aenovra,
        "ERC721NonexistentToken"
      );
    });

    it("enforces max 10 mints per wallet", async function () {
      for (let i = 0; i < 10; i++) {
        await aenovra.connect(minter).mint({ value: PRICE });
      }
      expect(await aenovra.mintedBy(minter.address)).to.equal(10);
      expect(await aenovra.totalSupply()).to.equal(10);
      await expect(
        aenovra.connect(minter).mint({ value: PRICE })
      ).to.be.revertedWithCustomError(aenovra, "ExceedsWalletLimit");
      // A different wallet with an Agent ID can still mint.
      await registry.mintTo(stranger.address);
      await aenovra.connect(stranger).mint({ value: PRICE });
      expect(await aenovra.totalSupply()).to.equal(11);
    });

    it("lets the owner disable the Agent ID gate", async function () {
      await aenovra.connect(owner).setAgentIdCheckRequired(false);
      await aenovra.connect(stranger).mint({ value: PRICE });
      expect(await aenovra.ownerOf(1)).to.equal(stranger.address);
    });

    it("only the owner can change admin settings", async function () {
      await expect(aenovra.connect(minter).setMintActive(false))
        .to.be.revertedWithCustomError(aenovra, "OwnableUnauthorizedAccount");
      await expect(aenovra.connect(minter).setAgentIdCheckRequired(false))
        .to.be.revertedWithCustomError(aenovra, "OwnableUnauthorizedAccount");
      await expect(aenovra.connect(minter).setBaseURI("https://example.com/"))
        .to.be.revertedWithCustomError(aenovra, "OwnableUnauthorizedAccount");
      await expect(aenovra.connect(minter).setRevenueWallet(stranger.address))
        .to.be.revertedWithCustomError(aenovra, "OwnableUnauthorizedAccount");
    });
  });

  describe("price admin", function () {
    it("owner can change the flat price before the first mint, not after", async function () {
      const newPrice = ethers.parseEther("0.0005");
      await aenovra.connect(owner).setMintPrice(newPrice);
      expect(await aenovra.currentPrice()).to.equal(newPrice);
      expect(await aenovra.mintPrice()).to.equal(newPrice);
      // Back to the spec price, then mint once and try again.
      await aenovra.connect(owner).setMintPrice(PRICE);
      await aenovra.connect(owner).setMintActive(true);
      await aenovra.connect(minter).mint({ value: PRICE });
      await expect(
        aenovra.connect(owner).setMintPrice(newPrice)
      ).to.be.revertedWithCustomError(aenovra, "PriceLocked");
      await expect(
        aenovra.connect(owner).setMintPrice(0)
      ).to.be.revertedWithCustomError(aenovra, "PriceLocked");
    });
  });

  describe("withdraw safety valve", function () {
    it("forwards force-sent funds to revenue and reverts when empty", async function () {
      await expect(aenovra.connect(owner).withdraw())
        .to.be.revertedWithCustomError(aenovra, "NoFunds");
      // Force-send 0.01 ETH outside mint() (as a selfdestruct would):
      // the contract has no receive/fallback, so simulate it by
      // setting its balance directly on the Hardhat network.
      // 0.01 ETH = 10^16 wei = 0x2386F26FC10000.
      await ethers.provider.send("hardhat_setBalance", [
        await aenovra.getAddress(),
        "0x2386F26FC10000",
      ]);
      const revenueBefore = await ethers.provider.getBalance(REVENUE);
      await aenovra.connect(owner).withdraw();
      expect(await ethers.provider.getBalance(await aenovra.getAddress())).to.equal(0);
      expect(await ethers.provider.getBalance(REVENUE)).to.equal(
        revenueBefore + ethers.parseEther("0.01")
      );
    });
  });
});
