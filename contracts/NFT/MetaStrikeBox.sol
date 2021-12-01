// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IMetaStrikeCore {
    function safeMint(address to, uint256 _weapon, uint256 _skin, uint8 _tier,  uint8 _slot) external;
}

/// @custom:security-contact security@metastrike.io
contract MetaStrikeBox is ERC721, ERC721Enumerable, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    address public metastrikeCore;

    struct BoxInfo {
        uint256 weapons;
        uint8 tier;
        uint256 skins;
        uint8[] slots;
        uint256[] weightedSlots;
    }

    mapping (uint8 => BoxInfo) public boxesInfo;
    mapping (uint8 => uint256) public boxTypeToTimeLock;
    mapping (uint256 => uint8) public idToBoxType;

    constructor(address _metastrikeCore) ERC721("MetaStrikeBox", "MTS_BOX") {
        metastrikeCore = _metastrikeCore;
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(PAUSER_ROLE, msg.sender);
        grantRole(MINTER_ROLE, msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://resource.metastrike.io/box/{id}.json";
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function ownedBy(address _user) external view returns (uint256[] memory nfts) {
        uint256 owning = ERC721.balanceOf(_user);
        nfts = new uint256[] (owning);
        for (uint256 i = 0; i < owning; i ++ ) { 
            nfts[i] = tokenOfOwnerByIndex(_user,i);
        }
    }

    function setupBox(uint8 _boxId, uint256 _weapons, uint8 _tier, uint256 _skin, uint8[] calldata _slots, uint256[] calldata _weightedSlots) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(boxesInfo[_boxId].weapons == 0, "Box already set up!");
        boxesInfo[_boxId] = BoxInfo(_weapons, _tier, _skin, _slots, _weightedSlots);
    }

    function safeMint(address to, uint8 _boxId) public onlyRole(MINTER_ROLE) {
        require(boxesInfo[_boxId].weapons != 0, "Box not set up!");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        idToBoxType[tokenId] = _boxId;
        _safeMint(to, tokenId);
    }

    function openBox(uint256 _id) external {
        require(msg.sender == tx.origin, "Nope lah!");
        burn(_id);
        BoxInfo memory boxInfo = boxesInfo[idToBoxType[_id]];
        uint256 weaponType = _randomUint256(boxInfo.weapons);
        uint256 weaponSkin = _randomUint256(boxInfo.skins);
        uint8 slotsDraw = boxInfo.slots[_weightedRandomArray(boxInfo.weightedSlots)];
        if (slotsDraw != 0) {
            IMetaStrikeCore(metastrikeCore).safeMint(msg.sender, weaponType, weaponSkin, boxInfo.tier, slotsDraw-1);
        }
    }

    // AUX
    function _weightedRandomArray(uint256[] memory weightedChoices) internal view returns (uint256) {
        uint256 sumOfWeight = 0;
        uint256 numChoices = weightedChoices.length;
        for(uint256 i=0; i<numChoices; i++) {
            sumOfWeight += weightedChoices[i];
        }
        uint256 rnd = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, gasleft(), msg.sender, sumOfWeight)));
        rnd = rnd % sumOfWeight;
        for(uint256 i=0; i<numChoices; i++) {
            if(rnd < weightedChoices[i])
                return i;
            rnd -= weightedChoices[i];
        }
        return 0;
    }

    function _randomUint256(uint256 ranged) internal view returns (uint256 rnd) {
        rnd = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, gasleft(), msg.sender)));
        rnd = rnd % ranged;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
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