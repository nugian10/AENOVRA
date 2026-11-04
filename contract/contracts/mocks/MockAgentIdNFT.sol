// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Test-only mock of the SPACE ID .ai Agent ID NFT.
/// Mimics the real registry's balanceOf check: an address holds
/// an Agent ID when it owns at least one of these tokens.
/// mintBatch lets tests give many wallets an Agent ID in one tx.
contract MockAgentIdNFT is ERC721 {
    uint256 private _nextId = 1;

    constructor() ERC721("Mock Agent ID", "MAID") {}

    function mintTo(address to) external returns (uint256 tokenId) {
        tokenId = _nextId++;
        _mint(to, tokenId);
    }

    function mintBatch(address[] calldata recipients) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], _nextId++);
        }
    }
}

/// @notice Test-only contract caller, used to prove mint()
/// rejects calls from contracts (NoContracts).
contract MockCaller {
    function tryMint(address aenovra) external payable returns (bool ok) {
        (ok, ) = aenovra.call{value: msg.value}(
            abi.encodeWithSignature("mint()")
        );
    }
}
