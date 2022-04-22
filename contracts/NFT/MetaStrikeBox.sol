// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

interface IMetaStrikeCore {
    function safeMint(address to, uint256 _weapon, uint256 _skin, uint8 _color, uint8 _tier,  uint8 _slot, uint256 _timeLock) external;
}

/// @custom:security-contact security@metastrike.io
contract MetaStrikeBox is ERC1155, Pausable, AccessControl, ERC1155Burnable, VRFConsumerBaseV2 {

    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public metastrikeCore;
    string public constant name = "Metastrike Box";

    struct BoxInfo {
        uint256 weapons;
        uint8 tier;
        uint256 skins;
        uint8 colors;
        uint8[] slots;
        uint256[] weightedSlots;
    }
    
    struct SellInfo {
        uint8 boxId;
        address paymentToken;
        uint256 price;
        uint256 totalAmount;
        uint256 purchased;
    }

    mapping (uint256 => BoxInfo) public boxesInfo;
    mapping (uint8 => SellInfo) public sellInfo;
    mapping (uint8 => uint256) public boxTypeToTimeLock;

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    uint64 s_subscriptionId;
    address vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;
    address link = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    bytes32 keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;
    uint32 callbackGasLimit = 1500000;
    uint16 requestConfirmations = 3;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;
    uint32 numWords =  1;

    struct RequestInfo {
        address boxOwner;
        uint256 boxId;
        uint256[] randomReses;
    }

    mapping(uint256 => RequestInfo) public RequestInfos;

    mapping(uint256 => address) public s_requestIdToBoxOwer;
    mapping(uint256 => uint256) public s_requestIdToBoxId; 
    mapping(uint256 => uint256[]) public s_requestIdToRandom;

    event BoxBought(address buyer, uint8 sellId, uint8 boxId, uint256 amount);

    constructor(address _metastrikeCore,uint64 subscriptionId) ERC1155("https://resource.metastrike.io/box/{id}.json") VRFConsumerBaseV2(vrfCoordinator) {
        metastrikeCore = _metastrikeCore;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
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

    function setupSell(uint8 _sellId, uint8 _boxId, address _paymentToken, uint256 _price, uint256 _totalAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 purchased;
        if (sellInfo[_sellId].purchased != 0) {
            purchased = sellInfo[_sellId].purchased;
        }
        sellInfo[_sellId] = SellInfo(_boxId, _paymentToken, _price, _totalAmount, purchased);
    }

    function buyBox(uint8 _sellId, uint256 _amount, bytes memory data) public {
        SellInfo storage deal = sellInfo[_sellId];
        require(deal.purchased + _amount <= deal.totalAmount, "Box was out of stock");
        IERC20(deal.paymentToken).safeTransferFrom(msg.sender, address(this), deal.price * _amount);
        deal.purchased += _amount;
        _mint(msg.sender, deal.boxId, _amount, data);
        emit BoxBought(msg.sender, _sellId, deal.boxId, _amount);
    }

    function claimFund(address _token, address _to, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_token == address(0)) {
			(bool success,) = _to.call{value : _amount}("");
			require(success, "Tranfer Native Failed!");
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
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

    function openBox(uint256 _id) external returns (uint256) {
        require(msg.sender == tx.origin, "Nope lah!");
        uint256 requestId = COORDINATOR.requestRandomWords(keyHash,s_subscriptionId,requestConfirmations,callbackGasLimit,numWords);
        RequestInfo storage requestInfo = RequestInfos[requestId];
        requestInfo.boxOwner = msg.sender;
        requestInfo.boxId = _id;
        s_requestIdToBoxOwer[requestId] = msg.sender;
        s_requestIdToBoxId[requestId] = _id ; 
        s_requestId = requestId;
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId,uint256[] memory randomWords) internal override {
        s_requestIdToRandom[requestId] = randomWords;
        address boxOwner = s_requestIdToBoxOwer[requestId];
        uint256 boxId = s_requestIdToBoxId[requestId];
        uint256 ran = randomWords[0];
        burn(boxOwner, boxId, 1);
        BoxInfo memory boxInfo = boxesInfo[boxId];
        uint256 weaponType = ran % boxInfo.weapons;
        uint256 weaponSkin = ran % boxInfo.skins;
        uint8 weaponColor = uint8(ran % boxInfo.colors);
        uint8 slotsDraw = boxInfo.slots[_weightedRandomArray(boxInfo.weightedSlots)];
        IMetaStrikeCore(metastrikeCore).safeMint(boxOwner, weaponType, weaponSkin, weaponColor, boxInfo.tier, slotsDraw-1, 600);
    }

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
