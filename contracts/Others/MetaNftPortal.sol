// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MetaVerifier.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
    
interface IMetaStrikeCore {
    function safeMint(address to, uint8 _weaponCat, uint256 _weapon, uint256 _skin, uint8 _color, uint8 _tier,  uint8 _slot, uint256 _point, uint256 _timeLock) external;
	function getCurrentTokenId() external view returns(uint256);
}

interface IERC1155Mintable is IERC1155 {
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;
}

contract MetaNftPortal is MetaVerifier, Ownable, ERC1155Holder, ERC721Holder {

	using Address for address;
	using SafeERC20 for IERC20;

    address public metastrikeCore;
	address public metaEarnedBox;
	
	mapping(address => uint256) public nonces;

	struct NftInfo {
		bool allowed;
		bool isERC1155;
	}

	mapping (address => NftInfo) public nfts;

	event SignerUpdated(address newSigner);
	event NftDeposited(address indexed user,address nftAddress,uint256 nftId,uint256 nftAmount,bool isERC1155);
    event UpgradedNftClaimed(address indexed user,address nftAddress,uint256 oldNftId,uint256 newNftId,uint256 nonce);
    event NonUpgradeNftClaimed(address indexed user,address nftAddress,uint256 nftId,uint256 nftAmount, uint256 nonce);
	event EarnedBoxClaimed(address indexed user, uint256 boxId, uint256 amount, uint256 nonce);

	constructor(address _signer,address _metastrikeCore,address _metaEarnedBox) MetaVerifier(_signer) {
        metastrikeCore = _metastrikeCore;
		metaEarnedBox = _metaEarnedBox;
	}

    function getEarnedBoxMessageHash(
        address account,
        uint256 nftid,
        uint256 amount,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), account, nftid, amount, nonce));
    }

    function getNonUpgradedMessageHash(
        address account,
		address nftAddress,
        uint256 nftid,
        uint256 amount,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), account, nftAddress, nftid, amount, nonce));
    }

    function getUpgradedNftMessageHash(
        address account,
        uint8 weaponCat,
		uint256 weaponType,
		uint256 weaponSkin,
		uint8 weaponColor,
		uint8 tier,
        uint8 slots,
		uint256 points,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), account,weaponCat, weaponType, weaponSkin, weaponColor, tier, slots, points, nonce));
    }

	function configNftType(address _nftAddress, bool _allow, bool _isERC1155) public onlyOwner {
		nfts[_nftAddress] = NftInfo(_allow, _isERC1155);
	}

	function updateSigner(address _newSigner) external onlyOwner {
        signer = _newSigner;
        emit SignerUpdated(_newSigner);
    }

	function depositNft(address[] calldata _nftAddress,uint256[] calldata _nftId,uint256[] calldata _nftAmount) external {
		require(_nftAddress.length == _nftId.length&&_nftId.length ==  _nftAmount.length,"depositNft: Input mismatched!");
		for (uint256 i = 0; i < _nftAddress.length; i ++ ) {
			require(nfts[_nftAddress[i]].allowed, "depositNft: This nft was NOT accepted!");
			_transferAsset(msg.sender, address(this), _nftAddress[i], _nftId[i], _nftAmount[i], "0x");
			emit NftDeposited(msg.sender, _nftAddress[i], _nftId[i], _nftAmount[i],nfts[_nftAddress[i]].isERC1155);
		}
	}

	function claimUpgradedNft(uint256 oldNftId,uint8 weaponCat,uint256 weaponType,uint256 weaponSkin,uint8 weaponColor,uint8 tier,uint8 slots,uint256 points,bytes calldata signature) external{
		uint256 currentNonce = nonces[msg.sender]++;
        bytes32 messageHash = getUpgradedNftMessageHash(msg.sender, weaponCat, weaponType, weaponSkin, weaponColor, tier, slots, points,currentNonce);
		require(verify(messageHash, signature), "claimUpgradedNft: Invalid Signature");
		IMetaStrikeCore(metastrikeCore).safeMint(msg.sender, weaponCat, weaponType, weaponSkin, weaponColor, tier, slots, points, 0);
        emit UpgradedNftClaimed(msg.sender,metastrikeCore,oldNftId,IMetaStrikeCore(metastrikeCore).getCurrentTokenId()-1,currentNonce);
	}

    function claimNonUpgradedNft(address _nftAddress,uint256 _nftId,uint256 _nftAmount,bytes calldata signature) public {
		uint256 currentNonce = nonces[msg.sender]++;
        bytes32 messageHash = getNonUpgradedMessageHash(msg.sender,_nftAddress, _nftId, _nftAmount, currentNonce);
		require(verify(messageHash, signature), "claimNonUpgraded: Invalid Signature");
        require(nfts[_nftAddress].allowed, "claimNonUpgraded: This nft was NOT accepted!");
		_transferAsset(address(this),msg.sender, _nftAddress, _nftId, _nftAmount, "0x");
        emit NonUpgradeNftClaimed(msg.sender, _nftAddress, _nftId, _nftAmount,currentNonce);
    }

	function claimEarnedBox(uint256 nftId, uint256 amount, bytes calldata signature) external {
        uint256 currentNonce = nonces[msg.sender]++;
        bytes32 messageHash = getEarnedBoxMessageHash(msg.sender, nftId, amount, currentNonce);
        require(verify(messageHash, signature), "claimEarnedBox: Invalid Signature");
        IERC1155Mintable(metaEarnedBox).mint(msg.sender, nftId, amount, "0x00");
        emit EarnedBoxClaimed(msg.sender, nftId, amount, currentNonce);
    }

	function _transferAsset(
		address from_,
		address to_,
		address nftAddress_,
		uint256 nftId_,
		uint256 amount_,
		bytes memory data_
	) private {
		if (nfts[nftAddress_].isERC1155) {
			IERC1155(nftAddress_).safeTransferFrom(from_, to_, nftId_, amount_, data_);
		} else {
			require(amount_ == 1, "MataNftPortal: ERC721 could NOT be fraud!");
			IERC721(nftAddress_).safeTransferFrom(from_, to_, nftId_, data_);
		}
	}
}