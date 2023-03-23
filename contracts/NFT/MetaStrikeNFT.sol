// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IMetal is IERC1155 {
    function getMetalInfo(uint256 metalId) external view returns (uint256, uint256);
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;
    function burn(address account, uint256 id, uint256 value) external;
}

interface VerichainsNetRegistry {
    function randomService(uint256 key) external returns(VerichainsNetRandomService);
}

interface VerichainsNetRandomService {
    function random() external returns(uint256);
}

/// @custom:security-contact security@metastrike.io
contract MetaStrikeCore is ERC721Enumerable, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    address public metalAddress;
    address public mtsToken;
    address public mttToken;
    uint256 public mtsAmountFee;
    uint256 public mttAmountFee;
    uint256 public mtsTotalAttachFee;
    uint256 public mttTotalAttachFee;

    address public randomRegistry;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private _tokenIdCounter;
    uint256 constant ONE_HUNDRED = 10000;
    uint256 constant randomKey = 0xc9821440a2c2cc97acac89148ac13927dead00238693487a9c84dfe89e28a284;
    uint8 public tiers;

    struct WeaponInfo {
        uint8 weaponCat;
        uint256 weaponType;
        uint256 skin;
        uint256 color;
        uint8 tier; // 0 = uncom; 1 = silver; 2 = gold; 3 = diamond
        uint8 slot;
        uint256 point;
        uint256 releaseTime;
    }

    mapping (uint256 => WeaponInfo) public weapons;
    mapping (uint8 => uint256) private _tierPoint;

    bool public attachOperating;
    

    /// @custom:oz-upgrades-unsafe-allow constructor

    event MetaStrikeMinted(address to, uint256 tokenId, uint8 _weaponCat, uint256 _weapon, uint256 _skin, uint8 _color, uint8 _tier, uint8 _slot, uint256 _points, uint256 _timeLock);
    event MetalAttached(address user, uint256 tokenId, uint256[] metals, bool[] result, uint8 newSlot, uint8 newTier, uint256 newPoint);
    event RandomNumber(uint256 _value);

    constructor() ERC721("MetaStrikeCore", "MTS_NFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function withdrawFee(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

	modifier whenAttachOperating() {
        require(attachOperating, "Attach: paused");
        _;
    }

    function updateOperation(bool newAttach) external onlyRole(DEFAULT_ADMIN_ROLE) {
        attachOperating = newAttach;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://resource.metastrike.io/mts/";
    }

    function setupMetalAddress(address newMetal) external onlyRole(DEFAULT_ADMIN_ROLE) {
        metalAddress = newMetal;
    }

    function setupFee(address newMts, address newMtt, uint256 newMtsFee, uint256 newMttFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mtsToken = newMts;
        mttToken = newMtt;
        mtsAmountFee = newMtsFee;
        mttAmountFee = newMttFee;
    }

    function setupRandomRegistry(address newRandomRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        randomRegistry = newRandomRegistry;
    }

    function setupTierPoint(uint256[] calldata points, uint8 _tiers) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tiers == points.length, 'Invalid configuration');
        tiers = _tiers;
        for (uint8 i = 0; i < points.length; i ++) {
            _tierPoint[i] = points[i];
        }
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

    function safeMint(address to, uint8 _weaponCat, uint256 _weapon, uint256 _skin, uint8 _color, uint8 _tier, uint8 _slot, uint256 _points, uint256 _timeLock) 
    public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        weapons[tokenId] = WeaponInfo(_weaponCat, _weapon, _skin, _color, _tier, _slot, _points, _timeLock);
        _tokenIdCounter.increment();
        emit MetaStrikeMinted(to, tokenId, _weaponCat, _weapon, _skin, _color, _tier, _slot, _points, _timeLock);
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        require(weapons[tokenId].releaseTime < block.timestamp, 'MetaStrike: This token was not be released!');
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
    
    // Advance MetaStrike NFT
    function attachMetal(uint256[] memory metalIds, uint256 tokenId) whenAttachOperating external {
        WeaponInfo storage weapon = weapons[tokenId];
        require(metalIds.length <= weapon.slot, "Insufficient slot!");
        require(ownerOf(tokenId) == msg.sender, "Insufficient ownership!");
        if (mtsToken != address(0) && mtsAmountFee > 0) {
            IERC20(mtsToken).safeTransferFrom(msg.sender, address(this), mtsAmountFee);
            mtsTotalAttachFee += mtsAmountFee;
        }
        if (mttToken != address(0) && mttAmountFee > 0) {
            IERC20(mttToken).safeTransferFrom(msg.sender, address(this), mttAmountFee);
            mttTotalAttachFee += mttAmountFee;
        }
        bool[] memory result = new bool[](metalIds.length);
        for (uint256 i = 0; i < metalIds.length; i ++ ) {
            IMetal(metalAddress).burn(msg.sender, metalIds[i], 1);
            uint256 ranNumber = _randomUint256(ONE_HUNDRED);
            (uint256 point, uint256 percent) = IMetal(metalAddress).getMetalInfo(metalIds[i]);
            if (ranNumber <= percent) {
                weapons[tokenId].slot -= 1;
                weapons[tokenId].point += point;
                result[i] = true;
                if (weapon.point > _tierPoint[weapon.tier + 1] && weapon.tier < tiers -1 ) {
                    weapon.tier += 1;
                }
            }
        }
        emit MetalAttached(msg.sender, tokenId, metalIds, result, weapon.slot, weapon.tier, weapon.point);
    }

    function _randomUint256(uint256 ranged) internal returns (uint256 randomNumber) {
        randomNumber = VerichainsNetRegistry(randomRegistry).randomService(MetaStrikeCore.randomKey).random();
        randomNumber = randomNumber % ranged;
        emit RandomNumber(randomNumber);
    }
}