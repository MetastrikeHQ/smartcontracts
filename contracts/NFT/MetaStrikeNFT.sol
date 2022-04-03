// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @custom:security-contact security@metastrike.io
contract MetaStrikeCore is ERC721Enumerable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;
    uint256[6] _nullMetal;

    struct WeaponInfo {
        uint256 weaponType;
        uint256 skin;
        uint256 color;
        uint8 tier; // 1 = uncom; 2 = silver; 3 = gold; 4 = diamond
        uint8 slot;
        uint256 releaseTime;
    }

    mapping (uint256 => WeaponInfo) public weapon;

    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() ERC721("MetaStrikeCore", "MTS_NFT") {
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(MINTER_ROLE, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://resource.metastrike.io/mts/{id}.json";
    }

    function getCurrentTokenId() external view returns (uint256 tokenId) {
        tokenId = _tokenIdCounter.current();
    }

    function ownedBy(address _user) external view returns (uint256[] memory nfts) {
        uint256 owning = ERC721.balanceOf(_user);
        nfts = new uint256[] (owning);
        for (uint256 i = 0; i < owning; i ++ ) { 
            nfts[i] = tokenOfOwnerByIndex(_user,i);
        }
    }

    function safeMint(address to, uint256 _weapon, uint256 _skin, uint8 _color, uint8 _tier,  uint8 _slot, uint256 _timeLock) 
    public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        weapon[tokenId] = WeaponInfo(_weapon, _skin, _color, _tier, _slot, _timeLock);
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        require(weapon[tokenId].releaseTime < block.timestamp, 'MetaStrike: This token was not be released!');
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}