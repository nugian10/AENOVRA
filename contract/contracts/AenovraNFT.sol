// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================
// AENOVRA — Star Relic NFT Collection
// ERC-721, BNB Smart Chain Mainnet (Chain ID 56)
// ------------------------------------------------------------
// Modelled on the proven OOBIX v2 / MythRealm v2 pattern
// (WEDO model), adapted to the Aenovra spec confirmed by
// Nugraha 4 Nov 2026:
//
// - Name "Aenovra", symbol "AENO", MAX_SUPPLY 5,555.
//   Token IDs 1–5,555, sequential.
// - FLAT price: 0.0003 BNB for every token.
//   currentPrice() returns 0.0003 BNB. Payment must equal
//   it exactly — under- and overpayment both revert.
// - mint() takes NO arguments and mints exactly 1 token
//   per call. Selector 0x1249c58b == keccak("mint()")[:4].
// - Gacha deck: a fixed deck of slots is committed before
//   launch. Mint #n opens deck slot #n, rarity is revealed
//   instantly in the Minted event. deckHash() is the SHA-256
//   commitment of the whole deck (generator's convention —
//   see the deckHash() docs).
// - Agent-only enforced ON-CHAIN by a SPACE ID Agent ID
//   check: the minter must hold a SPACE ID .ai Agent ID
//   NFT (registry 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F,
//   the public registry also used by WEDO / Nomio /
//   AnthroBit / Spoxy). hasAgentId uses a low-level
//   staticcall on purpose: a high-level balanceOf call
//   to an address with no code returns empty data, and
//   the ABI decoder reverts on empty returndata OUTSIDE
//   try/catch. The owner can disable the check
//   (setAgentIdCheckRequired) or point it at a different
//   registry (setAgentIdRegistry).
// - Calls from contracts are rejected (NoContracts).
// - MAX 10 MINTS PER WALLET, enforced on-chain
//   (mintedBy mapping). The 11th mint() from the same
//   wallet reverts ExceedsWalletLimit.
// - Rarity tiers (5):
//     0 Common, 1 Uncommon, 2 Rare, 3 Epic, 4 Legendary
//   Exact deck counts: Common 3333, Uncommon 1333,
//   Rare 555, Epic 250, Legendary 84 = 5,555.
// - The mint seed is stored on-chain at mint.
// - No public mint button and no direct public mint
//   function on the site — the website is informational
//   only; only an authorized mint agent calls mint().
//
// THE DECK — design + honest limits:
//   The deck is generated OFF-CHAIN by a deterministic
//   seeded shuffle (scripts/deck.json, seed
//   "AENOVRA-DECK-SEED-2026-11-04-v1", mulberry32 +
//   Fisher-Yates) and passed to the constructor as
//   5,555 bytes (1 byte per token, tier code 0–4).
//   It is stored ON-CHAIN in full (_deck) and the
//   constructor verifies the exact tier counts, so a
//   wrong deck cannot be deployed by accident.
//   deckHash() = SHA-256 commitment of the whole deck, in the
//   generator's convention: SHA-256 of the deck's COMPACT JSON
//   encoding ("[0,0,1,2,...]"). It equals the deckHash recorded
//   in deck.json / collection.json — anyone can re-run the
//   generator and check the commitment. NOTE: this is NOT
//   keccak256 of the raw deck bytes (that would be a different
//   value); the generator used SHA-256 over JSON, and the
//   contract follows the generator so the on-chain value
//   matches the recorded one exactly.
//   Expected deckHash:
//   0xe83281f313b66ab004bb65d41ed51cf2de152aa9959031f95ce39acb36c74fa4
//   Mint #n draws deck slot #n; rarityOf(tokenId)
//   returns that slot's tier; tokenRarity[tokenId]
//   is stored at mint and emitted in Minted.
//   HONEST LIMITS: (1) the deck is a rarity
//   assignment, not artwork generation — artwork is
//   pre-generated per token ID; the deck only decides
//   which rarity tier token #n is. (2) The deck is
//   fixed at deploy and cannot be reshuffled
//   afterwards. (3) The seed is public (it has to be,
//   for the commitment to be verifiable), so anyone
//   can compute the whole deck in advance — rarity is
//   transparent, not secret. That is the WEDO gacha
//   trade-off, kept deliberately.
//
// OWNER / REVENUE — constructor parameters, NOT
// hard-coded (except the public Agent ID registry
// default). CONFIRMED by Nugraha 4 Nov 2026:
// owner = My Wallet 0x0262e8e5E4584D8AB840fD950a6E2E0A414d4097,
// revenue = Binance Agentic Wallet
// 0x89c37649Ba3BAA9E1ce028612b7DE4e9c3a947B7.
// Funds: each mint forwards msg.value DIRECTLY to
// the revenue (Agentic) wallet inside the same mint()
// call. Mint payments NEVER sit in this contract, and
// no withdraw step is needed for them. withdraw()
// exists only as a safety valve for funds that arrive
// outside mint() (e.g. force-sent ETH).
//
// STORAGE: GitHub (OOBIX way), NOT IPFS. baseURI =
// https://raw.githubusercontent.com/nugian10/AENOVRA/main/collection/metadata/
// tokenURI = baseURI + tokenId + ".json".
//
// This contract is SOURCE-VERIFIABLE on BscScan.
// It is NOT an independent audit — keep that
// disclosure on the site.
// ============================================================

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AenovraNFT is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 5555;
    uint256 public constant MAX_PER_WALLET = 10;

    // Rarity tier codes.
    uint8 public constant RARITY_COMMON = 0;
    uint8 public constant RARITY_UNCOMMON = 1;
    uint8 public constant RARITY_RARE = 2;
    uint8 public constant RARITY_EPIC = 3;
    uint8 public constant RARITY_LEGENDARY = 4;

    // Exact deck counts — enforced by the constructor.
    uint256 public constant COUNT_COMMON = 3333;
    uint256 public constant COUNT_UNCOMMON = 1333;
    uint256 public constant COUNT_RARE = 555;
    uint256 public constant COUNT_EPIC = 250;
    uint256 public constant COUNT_LEGENDARY = 84;

    /// @notice Flat mint price for every token.
    uint256 public constant MINT_PRICE = 0.0003 ether;

    /// @notice SPACE ID .ai Agent ID NFT on BNB Smart Chain.
    /// Public registry used by WEDO / Nomio / AnthroBit / Spoxy.
    address public constant DEFAULT_AGENT_ID_REGISTRY =
        0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    uint256 public mintPrice = MINT_PRICE;

    bool public mintActive;
    address public revenueWallet;
    address public agentIdRegistry;
    bool public agentIdCheckRequired = true;

    string private _baseTokenURI;
    uint256 private _nextTokenId = 1;

    /// @dev The full gacha deck, 1 byte per token (tier 0–4),
    /// stored on-chain. deckHash() commits to it.
    bytes private _deck;

    /// @dev On-chain mint seed per token.
    mapping(uint256 => bytes32) public tokenSeed;
    /// @dev Rarity tier per minted token (deck slot value).
    mapping(uint256 => uint8) public tokenRarity;
    /// @dev Mints per wallet — ENFORCED: max 10 per wallet.
    mapping(address => uint256) public mintedBy;

    event Minted(address indexed minter, uint256 indexed tokenId, uint256 price, uint8 rarity, bytes32 seed);
    event DeckCommitted(bytes32 indexed deckHash);
    event MintActiveChanged(bool active);
    event BaseURIUpdated(string baseURI);
    event RevenueWalletUpdated(address indexed revenueWallet);
    event AgentIdRegistryUpdated(address indexed agentIdRegistry);
    event AgentIdCheckChanged(bool required);
    event MintPriceUpdated(uint256 mintPrice);
    event Withdrawn(address indexed revenueWallet, uint256 amount);

    error MintInactive();
    error ExceedsMaxSupply();
    error SoldOut();
    error IncorrectPayment(uint256 expected, uint256 received);
    error ExceedsWalletLimit(uint256 limit);
    error InvalidAddress();
    error InvalidDeck();
    error NoFunds();
    error NoAgentId();
    error NoContracts();
    error PriceLocked();
    error InvalidPrice();
    error PaymentForwardFailed();

    constructor(
        address initialOwner,
        address revenueWallet_,
        address agentIdRegistry_,
        string memory baseURI_,
        bytes memory deck_
    ) ERC721("Aenovra", "AENO") Ownable(initialOwner) {
        if (initialOwner == address(0) || revenueWallet_ == address(0) || agentIdRegistry_ == address(0)) {
            revert InvalidAddress();
        }
        if (deck_.length != MAX_SUPPLY) revert InvalidDeck();
        // Verify the exact tier counts on-chain, so a wrong
        // deck cannot be deployed by accident.
        uint256 c0;
        uint256 c1;
        uint256 c2;
        uint256 c3;
        uint256 c4;
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            uint8 tier = uint8(deck_[i]);
            if (tier == 0) c0++;
            else if (tier == 1) c1++;
            else if (tier == 2) c2++;
            else if (tier == 3) c3++;
            else if (tier == 4) c4++;
            else revert InvalidDeck();
        }
        if (
            c0 != COUNT_COMMON || c1 != COUNT_UNCOMMON || c2 != COUNT_RARE || c3 != COUNT_EPIC ||
            c4 != COUNT_LEGENDARY
        ) revert InvalidDeck();

        revenueWallet = revenueWallet_;
        agentIdRegistry = agentIdRegistry_;
        _baseTokenURI = baseURI_;
        _deck = deck_;
        emit DeckCommitted(deckHash());
    }

    // ---------- supply / pricing (read-only, for UI + agents) ----------

    function totalSupply() public view returns (uint256) {
        return _nextTokenId - 1;
    }

    /// @notice Alias of totalSupply().
    function totalMinted() public view returns (uint256) {
        return totalSupply();
    }

    function nextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice True when minting is open (mintActive).
    function mintOpen() public view returns (bool) {
        return mintActive;
    }

    /// @notice Price of a single token ID. Reverts outside 1..MAX_SUPPLY.
    function priceForTokenId(uint256 tokenId) public view returns (uint256) {
        if (tokenId == 0 || tokenId > MAX_SUPPLY) revert ExceedsMaxSupply();
        return mintPrice;
    }

    /// @notice Price of the next NFT to be minted. Reverts when sold out.
    /// The agent reads this and sends exactly this value with mint().
    function currentPrice() public view returns (uint256) {
        if (_nextTokenId > MAX_SUPPLY) revert SoldOut();
        return priceForTokenId(_nextTokenId);
    }

    /// @notice Alias of currentPrice().
    function getMintPrice() public view returns (uint256) {
        return currentPrice();
    }

    /// @notice SHA-256 commitment of the full on-chain deck.
    /// Convention (from the deck generator, art/generate.py):
    /// the recorded deckHash is the SHA-256 of the deck's
    /// COMPACT JSON encoding, e.g. "[0,0,1,2,...]" — the
    /// same value stored in deck.json / collection.json.
    /// This function rebuilds that exact encoding from the
    /// stored deck and hashes it, so the on-chain value
    /// equals the recorded one. Expected:
    /// 0xe83281f313b66ab004bb65d41ed51cf2de152aa9959031f95ce39acb36c74fa4
    /// (NOTE: this is NOT keccak256 of the raw deck bytes —
    /// that would be a different value. The generator used
    /// SHA-256 over JSON, so the contract follows the
    /// generator. Anyone can verify it off-chain with:
    /// sha256(json.dumps(deck, separators=(",", ":")).encode()).)
    function deckHash() public view returns (bytes32) {
        // "[" + 5,555 digits + 5,554 commas + "]" = 11,111 bytes.
        bytes memory json = new bytes(11111);
        json[0] = "[";
        uint256 p = 1;
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            json[p++] = bytes1(uint8(48) + uint8(_deck[i]));
            if (i + 1 < MAX_SUPPLY) json[p++] = ",";
        }
        json[p] = "]";
        return sha256(json);
    }

    /// @notice Rarity tier of a token ID (its deck slot), 0 Common,
    /// 1 Uncommon, 2 Rare, 3 Epic, 4 Legendary. Works before the
    /// token is minted — the deck is public by design.
    function rarityOf(uint256 tokenId) public view returns (uint8) {
        if (tokenId == 0 || tokenId > MAX_SUPPLY) revert ExceedsMaxSupply();
        return uint8(_deck[tokenId - 1]);
    }

    /// @notice True when `wallet` holds at least one SPACE ID
    /// .ai Agent ID NFT in the configured registry. A registry
    /// that does not answer like an ERC-721 returns false
    /// instead of reverting, so a bad registry address can
    /// never brick reads — it only blocks minting.
    /// Implemented with a low-level staticcall on purpose: a
    /// high-level balanceOf call to an address with no code
    /// returns empty data, and the ABI decoder reverts on
    /// empty returndata OUTSIDE try/catch. The low-level call
    /// returns ok=false / short data instead, which we map
    /// to false here.
    function holdsAgentId(address wallet) public view returns (bool) {
        if (agentIdRegistry == address(0)) return false;
        (bool ok, bytes memory data) = agentIdRegistry.staticcall(
            abi.encodeWithSelector(IERC721.balanceOf.selector, wallet)
        );
        if (!ok || data.length < 32) return false;
        return abi.decode(data, (uint256)) > 0;
    }

    /// @notice Alias of holdsAgentId().
    function hasAgentId(address wallet) public view returns (bool) {
        return holdsAgentId(wallet);
    }

    // ---------- minting ----------

    /// @notice Mint exactly ONE Aenovra relic to msg.sender.
    /// No arguments — the token ID is the next sequential one
    /// and opens deck slot #tokenId. Requires, in order:
    /// mint active; caller is not a contract; caller holds
    /// an Agent ID (unless the check is disabled); supply
    /// remains; caller is under the 10-per-wallet cap;
    /// msg.value equals currentPrice() exactly.
    /// Stores the mint seed and the deck rarity.
    /// PAYMENT FLOW: the mint forwards msg.value DIRECTLY
    /// to the revenue wallet in this same call — it never
    /// sits in this contract. If the forward fails, the
    /// whole mint reverts, so no token is ever minted
    /// without payment landing.
    function mint() external payable nonReentrant {
        if (!mintActive) revert MintInactive();
        if (msg.sender.code.length > 0) revert NoContracts();
        if (agentIdCheckRequired && !holdsAgentId(msg.sender)) revert NoAgentId();

        uint256 tokenId = _nextTokenId;
        if (tokenId > MAX_SUPPLY) revert SoldOut();
        if (mintedBy[msg.sender] >= MAX_PER_WALLET) revert ExceedsWalletLimit(MAX_PER_WALLET);
        uint256 price = priceForTokenId(tokenId);
        if (msg.value != price) revert IncorrectPayment(price, msg.value);

        uint8 rarity = uint8(_deck[tokenId - 1]);
        _nextTokenId++;
        bytes32 seed = keccak256(
            abi.encodePacked(blockhash(block.number - 1), msg.sender, tokenId)
        );
        tokenSeed[tokenId] = seed;
        tokenRarity[tokenId] = rarity;
        mintedBy[msg.sender]++;
        _safeMint(msg.sender, tokenId);
        emit Minted(msg.sender, tokenId, price, rarity, seed);

        if (price > 0) {
            (bool ok, ) = revenueWallet.call{value: price}("");
            if (!ok) revert PaymentForwardFailed();
        }
    }

    // ---------- metadata ----------

    function baseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice tokenURI = baseURI + tokenId + ".json".
    /// The base URI must therefore end with "/" and point at
    /// the folder holding those files, e.g. a GitHub raw
    /// folder URL.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert ERC721NonexistentToken(tokenId);
        return string.concat(_baseTokenURI, tokenId.toString(), ".json");
    }

    // ---------- owner-only administration ----------

    function setMintActive(bool active) external onlyOwner {
        mintActive = active;
        emit MintActiveChanged(active);
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        emit BaseURIUpdated(baseURI_);
    }

    function setRevenueWallet(address revenueWallet_) external onlyOwner {
        if (revenueWallet_ == address(0)) revert InvalidAddress();
        revenueWallet = revenueWallet_;
        emit RevenueWalletUpdated(revenueWallet_);
    }

    /// @notice Point the Agent ID check at a different registry
    /// (e.g. if SPACE ID migrates the .ai NFT contract).
    function setAgentIdRegistry(address agentIdRegistry_) external onlyOwner {
        if (agentIdRegistry_ == address(0)) revert InvalidAddress();
        agentIdRegistry = agentIdRegistry_;
        emit AgentIdRegistryUpdated(agentIdRegistry_);
    }

    /// @notice Turn the on-chain Agent ID check on/off.
    /// Turning it OFF makes minting permissionless on-chain and
    /// agent-only in the UI only (the Mythora pattern). The
    /// change is public on-chain via this event — do not hide it.
    function setAgentIdCheckRequired(bool required) external onlyOwner {
        agentIdCheckRequired = required;
        emit AgentIdCheckChanged(required);
    }

    /// @notice Change the flat mint price — ONLY before the
    /// first mint. Once totalSupply > 0 the price is locked.
    function setMintPrice(uint256 mintPrice_) external onlyOwner {
        if (totalSupply() > 0) revert PriceLocked();
        if (mintPrice_ == 0) revert InvalidPrice();
        mintPrice = mintPrice_;
        emit MintPriceUpdated(mintPrice_);
    }

    /// @notice Safety valve only: send any balance that
    /// arrived OUTSIDE mint() (e.g. force-sent ETH) to the
    /// revenue wallet. Owner-only. Mint payments are
    /// forwarded directly by mint() and never accumulate
    /// here, so in normal operation this reverts NoFunds.
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NoFunds();
        (bool ok, ) = revenueWallet.call{value: amount}("");
        if (!ok) revert("Withdraw failed");
        emit Withdrawn(revenueWallet, amount);
    }
}
