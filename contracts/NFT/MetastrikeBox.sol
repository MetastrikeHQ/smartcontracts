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
    function safeMint(address to, uint8 _weaponCat, uint256 _weapon, uint256 _skin, uint8 _color, uint8 _tier,  uint8 _slot, uint256 _point, uint256 _timeLock) external;
}

interface VerichainsNetRegistry {
    function randomService(uint256 key) external returns(VerichainsNetRandomService);
}

interface VerichainsNetRandomService {
    function random() external returns(uint256);
}

/// @custom:security-contact security@metastrike.io
contract MetaStrikeBox is ERC1155, Pausable, AccessControl, ERC1155Burnable, VRFConsumerBaseV2 {

    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public metastrikeCore;
    address public mtsToken;
    address public mttToken;
    uint256 public mtsTotalFee;
    uint256 public mttTotalFee;
    mapping(address => uint256) public totalBoxSale;
    string public constant name = "Metastrike Box";
    string public constant ticker = "MTB";
    uint256 constant randomKey = 0xc9821440a2c2cc97acac89148ac13927dead00238693487a9c84dfe89e28a284;
    address public randomRegistry;

    struct BoxInfo {
        uint256 mtsFee;
        uint256 mttFee;
        uint8 weaponCat;
        uint256 weapons;
        uint256 skins;
        uint8 colors;
        uint8 tier;
        uint256 points;
        uint8[] slots;
        uint256[] weightedSlots;
    }
    
    struct SellInfo {
        uint8 boxId;
        address paymentToken;
        uint256 price;
        uint256 totalAmount;
        uint256 startDate;
        uint256 endDate;
        uint256 purchased;
    }

    bool public openBoxOperating;
    bool public openBox2Operating;

    mapping (uint256 => BoxInfo) public boxesInfo;
    mapping (uint8 => SellInfo) public sellInfo;
    mapping (uint8 => uint256) public boxTypeToTimeLock;

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    uint64 s_subscriptionId;
    address vrfCoordinator = 0xc587d9053cd1118f25F645F9E08BB98c9712A4EE;
    address link = 0x404460C6A5EdE2D891e8297795264fDe62ADBB75;
    bytes32 keyHash = 0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04;
    uint32 callbackGasLimit = 1500000;
    uint16 requestConfirmations = 3;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;
    uint32 numWords =  1;

    mapping(uint256 => address) public s_requestIdToBoxOwer;
    mapping(uint256 => uint256) public s_requestIdToBoxId; 
    mapping(uint256 => uint256[]) public s_requestIdToRandom;

    event BoxBought(address buyer, uint8 sellId, uint8 boxId, uint256 amount);

    constructor(address _metastrikeCore, uint64 subscriptionId) ERC1155("https://resource.metastrike.io/box/{id}.json") VRFConsumerBaseV2(vrfCoordinator) {
        metastrikeCore = _metastrikeCore;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function setupFeeMtsToken(address newMts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mtsToken = newMts;
    }

    function setupFeeMttToken(address newMtt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mttToken = newMtt;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setupRandomRegistry(address newRandomRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        randomRegistry = newRandomRegistry;
    }

    modifier whenOpenBoxOperating() {
        require(openBoxOperating, "OpenBox: paused");
        _;
    }

    function updateOpenBoxOperating(bool newOpen) external onlyRole(DEFAULT_ADMIN_ROLE) {
        openBoxOperating = newOpen;
    }

    modifier whenOpenBox2Operating() {
        require(openBoxOperating, "OpenBox2: paused");
        _;
    }

    function updateOpenBox2Operating(bool newOpen2) external onlyRole(DEFAULT_ADMIN_ROLE) {
        openBox2Operating = newOpen2;
    }

    function setupBox(uint8 _boxId, BoxInfo memory _boxInfo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        boxesInfo[_boxId] = _boxInfo;
    }

    function setupSell(uint8 _sellId, uint8 _boxId, address _paymentToken, uint256 _price, uint256 _totalAmount, uint256 _startDate, uint256 _endDate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 purchased;
        if (sellInfo[_sellId].purchased != 0) {
            purchased = sellInfo[_sellId].purchased;
        }
        sellInfo[_sellId] = SellInfo(_boxId, _paymentToken, _price, _totalAmount, _startDate, _endDate, purchased);
    }

    function buyBox(uint8 _sellId, uint256 _amount, bytes memory data) public {
        SellInfo storage deal = sellInfo[_sellId];
        require(block.timestamp >= deal.startDate && block.timestamp <= deal.endDate, "Box is not available!");
        require(deal.purchased + _amount <= deal.totalAmount, "Box was out of stock");
        IERC20(deal.paymentToken).safeTransferFrom(msg.sender, address(this), deal.price * _amount);
        totalBoxSale[deal.paymentToken] += deal.price * _amount;
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

    function openBox(uint256 _id) whenOpenBoxOperating external returns (uint256) {
        require(msg.sender == tx.origin, "Nope lah!");
        BoxInfo memory boxInfo = boxesInfo[_id];
        burn(msg.sender, _id, 1);
        if (mtsToken != address(0) && boxInfo.mtsFee > 0) {
            IERC20(mtsToken).safeTransferFrom(msg.sender, address(this), boxInfo.mtsFee);
            mtsTotalFee += boxInfo.mtsFee;
        }
        if (mttToken != address(0) && boxInfo.mttFee > 0) {
            IERC20(mttToken).safeTransferFrom(msg.sender, address(this), boxInfo.mttFee);
            mttTotalFee += boxInfo.mttFee;
        }
        uint256 requestId = COORDINATOR.requestRandomWords(keyHash,s_subscriptionId,requestConfirmations,callbackGasLimit,numWords);
        s_requestIdToBoxOwer[requestId] = msg.sender;
        s_requestIdToBoxId[requestId] = _id ;
        s_requestId = requestId;
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId,uint256[] memory randomWords) internal override {
        s_requestIdToRandom[requestId] = randomWords;
        address boxOwner = s_requestIdToBoxOwer[requestId];
        uint256 boxId = s_requestIdToBoxId[requestId];
        uint256 rand = randomWords[0];
        BoxInfo memory boxInfo = boxesInfo[boxId];
        uint8 weaponCat =  boxInfo.weaponCat;
        uint256 weaponType = rand % boxInfo.weapons;
        uint256 weaponSkin = rand % boxInfo.skins;
        uint8 weaponColor = uint8(rand % boxInfo.colors);
        uint8 slotsDraw = boxInfo.slots[_weightedRandomArray(boxInfo.weightedSlots,rand)];
        IMetaStrikeCore(metastrikeCore).safeMint(boxOwner, weaponCat, weaponType, weaponSkin, weaponColor, boxInfo.tier, slotsDraw, boxInfo.points, 0);
    }

    function openBox2(uint256 _id) whenOpenBox2Operating external returns (uint256) {
        require(msg.sender == tx.origin, "Nope lah!");
        burn(msg.sender, _id, 1);
        BoxInfo memory boxInfo = boxesInfo[_id];
        if (mtsToken != address(0) && boxInfo.mtsFee > 0) {
            IERC20(mtsToken).safeTransferFrom(msg.sender, address(this), boxInfo.mtsFee);
            mtsTotalFee += boxInfo.mtsFee;
        }
        if (mttToken != address(0) && boxInfo.mttFee > 0) {
            IERC20(mttToken).safeTransferFrom(msg.sender, address(this), boxInfo.mttFee);
            mttTotalFee += boxInfo.mttFee;
        }
        uint256 randomNumber = VerichainsNetRegistry(randomRegistry).randomService(MetaStrikeBox.randomKey).random();
        uint8 weaponCat =  boxInfo.weaponCat;
        uint256 weaponType = randomNumber % boxInfo.weapons;
        uint256 weaponSkin = randomNumber % boxInfo.skins;
        uint8 weaponColor = uint8(randomNumber % boxInfo.colors);
        uint8 slotsDraw = boxInfo.slots[_weightedRandomArray(boxInfo.weightedSlots,randomNumber)];
        IMetaStrikeCore(metastrikeCore).safeMint(msg.sender, weaponCat, weaponType, weaponSkin, weaponColor, boxInfo.tier, slotsDraw, boxInfo.points, 0);
        return randomNumber;
    }

    function _weightedRandomArray(uint256[] memory weightedChoices, uint256 _ran) internal pure returns (uint256) {
        uint256 sumOfWeight = 0;
        uint256 numChoices = weightedChoices.length;
        for(uint256 i=0; i<numChoices; i++) {
            sumOfWeight += weightedChoices[i];
        }
        uint256 rnd = _ran;
        rnd = rnd % sumOfWeight;
        for(uint256 i=0; i<numChoices; i++) {
            if(rnd < weightedChoices[i])
                return i;
            rnd -= weightedChoices[i];
        }
        return 0;
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