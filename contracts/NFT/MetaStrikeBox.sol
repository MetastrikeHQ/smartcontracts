// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

interface IMetaStrikeCore {
    function safeMint(address to, uint256 _weapon, uint256 _skin, uint8 _color, uint8 _tier,  uint8 _slot) external;
}

/// @custom:security-contact security@metastrike.io
contract MetaStrikeBox is ERC1155, Pausable, AccessControl, ERC1155Burnable {

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public metastrikeCore;
    string public constant name = "";

    struct BoxInfo {
        uint256 weapons;
        uint8 tier;
        uint256 skins;
        uint8 colors;
        uint8[] slots;
        uint256[] weightedSlots;
    }

    mapping (uint256 => BoxInfo) public boxesInfo;
    mapping (uint8 => uint256) public boxTypeToTimeLock;

    constructor(address _metastrikeCore) ERC1155("https://resource.metastrike.io/box/{id}.json") {
        metastrikeCore = _metastrikeCore;
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(PAUSER_ROLE, msg.sender);
        grantRole(MINTER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setupBox(uint8 _boxId, uint256 _weapons, uint8 _tier, uint256 _skin, uint8 _color, uint8[] calldata _slots, uint256[] calldata _weightedSlots) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(boxesInfo[_boxId].weapons == 0, "Box already set up!");
        boxesInfo[_boxId] = BoxInfo(_weapons, _tier, _skin, _color, _slots, _weightedSlots);
    }
    
    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        require(boxesInfo[id].weapons != 0, "Box not set up!");
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    function openBox(uint256 _id) external {
        require(msg.sender == tx.origin, "Nope lah!");
        burn(msg.sender, _id, 1);
        BoxInfo memory boxInfo = boxesInfo[_id];
        uint256 weaponType = _randomUint256(boxInfo.weapons);
        uint256 weaponSkin = _randomUint256(boxInfo.skins);
        uint8 weaponColor = uint8(_randomUint256(boxInfo.colors));
        uint8 slotsDraw = boxInfo.slots[_weightedRandomArray(boxInfo.weightedSlots)];
        IMetaStrikeCore(metastrikeCore).safeMint(msg.sender, weaponType, weaponSkin, weaponColor, boxInfo.tier, slotsDraw-1);
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

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}