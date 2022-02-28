// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/// @custom:security-contact security@metastrike.io
contract MetaStrikeCore is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    CountersUpgradeable.Counter private _tokenIdCounter;
    uint256[6] _nullMetal;

    struct WeaponInfo {
        uint256 weaponType;
        uint256 skin;
        uint8 tier; // 1 = uncom; 2 = silver; 3 = gold; 4 = diamond
        uint8 slot;
        uint256 releaseTime;
    }

    mapping (uint256 => WeaponInfo) public weapon;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __ERC721_init("MetaStrikeCore", "MTS_NFT");
        __ERC721Enumerable_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://resource.metastrike.io/mts/{id}.json";
    }

    function getCurrentTokenId() external view returns (uint256 tokenId) {
        tokenId = _tokenIdCounter.current();
    }

    function ownedBy(address _user) external view returns (uint256[] memory nfts) {
        uint256 owning = ERC721Upgradeable.balanceOf(_user);
        nfts = new uint256[] (owning);
        for (uint256 i = 0; i < owning; i ++ ) { 
            nfts[i] = tokenOfOwnerByIndex(_user,i);
        }
    }

    function safeMint(address to, uint256 _weapon, uint256 _skin, uint8 _tier,  uint8 _slot, uint256 _timeLock) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        weapon[tokenId] = WeaponInfo(_weapon, _skin, _tier, _slot, _timeLock);
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        require(weapon[tokenId].releaseTime < block.timestamp, 'MetaStrike: This token was not be released!');
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}