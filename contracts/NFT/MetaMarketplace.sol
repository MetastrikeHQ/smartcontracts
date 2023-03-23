// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract MetaMarketplace is Ownable, ERC1155Holder, ERC721Holder {
	using Address for address;
	using SafeERC20 for IERC20;

	struct NftInfo {
		bool allowed;
		bool isERC1155;
	}

	mapping (address => NftInfo) public nfts;

	struct Listing {
		bool status;
		address seller;
		address nftAddress;
		uint256 nftId;
		uint256 quantity;
		uint256 availableQuantity;
		address paymentToken;
		uint256 unitPrice;
		uint256 startedAt; // set to zero if no specific time
		uint256 expiredAt; // set to zero if no specific time
	}

	struct Offer {
		bool status;
		address creator;
		uint256 listingId;
		uint256 amount;
		uint256 unitPrice;
	}

	Listing[] public listings;
	Offer[] public offers;

	bool public listingOperating;
	bool public offerOperating;

	mapping(address => bool) public isPaymentAccepted;

	// token address => amount , address(0) for nativeChainCoin
	mapping(address => uint256) public marketTreasury;

	uint256 private constant ONE_HUNDRED_PERCENT = 10 ** 5; // with 3 decimals
	uint256 private constant TEN_PERCENT = 10 ** 4; // with 3 decimals
	uint256 public marketFee;


	event ListingCreated(
		address indexed seller,
		uint256 indexed listingId,
		address indexed nftAddress,
		uint256 nftId,
		uint256 nftAmount,
		address paymentToken,
		uint256 unitPrice,
		uint256 startedAt,
		uint256 expiredAt
	);
	event AssetBought(address indexed buyer, uint256 indexed listingId, uint256 itemAmount);
	event ListingCanceled(uint256 indexed listingId);

	event OfferCreated(uint256 indexed offerId, address indexed offerCreator, uint256 indexed listingId, uint256 proposedAmount, uint256 proposedPrice);
	event OfferAccepted(uint256 indexed offerId);
	event OfferCanceled(uint256 indexed offerId);
	
	event MarketFeeUpdated(uint256 newMarketFee);


	// solhint-disable-next-line
	constructor(address _paymentToken, uint256 _marketFee) {
		setPaymentToken(address(0), true);
		setPaymentToken(_paymentToken, true);
		// Fee init
		updateMarketFee(_marketFee);
		listingOperating = true;

	}

	modifier whenListingOperating() {
        require(listingOperating, "Listing: paused");
        _;
    }

	modifier whenOfferOperating() {
        require(offerOperating, "Offer: paused");
        _;
    }

	function getNoListings() external view returns (uint256) {
		return listings.length;
	}

	/**
	 * @dev Withdraw payment fee in BNB from marketplace contract
	 * @param _to recipient address
	 * @param _tokenAddress Payment token address
	 */
	function withdraw(address payable _to, address _tokenAddress) external onlyOwner {
		require(marketTreasury[_tokenAddress] > 0, "MM: This treasury was not in pool!");
		_transfer(_tokenAddress, _to, marketTreasury[_tokenAddress]);
		marketTreasury[_tokenAddress] = 0;
	}

	function updateOperation(bool newListing, bool newOffer) external onlyOwner {
		listingOperating = newListing;
		offerOperating = newOffer;
	}

	/**
	 * @dev Owner setup payment token
	 * @param _tokenAddress Payment token address
	 * @param _allow boolean value indicating whether allow or not for token.
	 */
	function setPaymentToken(address _tokenAddress, bool _allow) public onlyOwner {
		isPaymentAccepted[_tokenAddress] = _allow;
	}

	/**
	 * @dev Owner pre-config nft
	 * @param _nftAddress Payment token address
	 * @param _allow  allow or not for nft address.
	 * @param _isERC1155 pre config which type of NFT.
	 */
	function configNftType(address _nftAddress, bool _allow, bool _isERC1155) public onlyOwner {
		nfts[_nftAddress] = NftInfo(_allow, _isERC1155);
	}

	/**
	 * @dev Transfer ERC20 or BNB
	 * @param _recipient Recipient address
	 * @param _amount Amount need to send
	 * @param _paymentToken Token address
	 */
	function _transfer(address _paymentToken, address payable _recipient, uint256 _amount) private {
		if (_paymentToken == address(0)) {
			(bool success,) = _recipient.call{value : _amount}("");
			require(success, "transfer-BNB-failed");
		} else {
			IERC20(_paymentToken).safeTransfer(_recipient, _amount);
		}
	}

	/**
	 * @dev Sets the market fee for each trade
	 * @param _fee - Share amount, from 0 to 10000 (0% -> 10%)
	 */
	function updateMarketFee(uint256 _fee) public onlyOwner {
		require(_fee <= TEN_PERCENT, "MM: Market Fee should less than 10%!");

		marketFee = _fee;
		emit MarketFeeUpdated(_fee);
	}

	/**
	 * @dev User create a listing
	 * @param _nftAddress ERC1155 address
	 * @param _nftId asset ID in ERC1155 contract
	 * @param _nftAmount NFT amount want to sell
	 * @param _unitPrice Price per selling asset
	 * @param _paymentToken ERC20 token address, skip is using BNB
	 * @param _startedAt start time that other can buy, , using timestamp (https://www.epochconverter.com/)
	 * @param _expiredAt selling expired time, set to 0 for listed forever, , using timestamp (https://www.epochconverter.com/)
	 *
	 * emit {ListingCreated} event
	 */
	function createListing(
		address _nftAddress,
		uint256 _nftId,
		uint256 _nftAmount,
		address _paymentToken,
		uint256 _unitPrice,
		uint256 _startedAt,
		uint256 _expiredAt
	) external whenListingOperating {
		require(nfts[_nftAddress].allowed, "MM: This nft was NOT accepted!");
		require(isPaymentAccepted[_paymentToken], "MM: This payment was NOT accepted!");
		require(_unitPrice > 0, "MM: The unitPrice should be greater than zero!");
		require(
			_expiredAt == 0 ||
			(_expiredAt > block.timestamp && _expiredAt > _startedAt),
			"MM:Invalid date setting!"
		);

		_transferAsset(msg.sender, address(this), _nftAddress, _nftId, _nftAmount, "0x");
		uint256 _listingId = listings.length;


		listings.push(
			Listing(
				true,
				msg.sender,
				_nftAddress,
				_nftId,
				_nftAmount,
				_nftAmount,
				_paymentToken,
				_unitPrice,
				_startedAt,
				_expiredAt
			)
		);
		emit ListingCreated(msg.sender, _listingId, _nftAddress, _nftId, _nftAmount, _paymentToken, _unitPrice, _startedAt, _expiredAt);
	}

	/**
	 * @dev User buy assets
	 * @param _listingId ID of listing items
	 * @param _itemAmount buying quantity
	 * emit {Buy} event
	 */
	function buyAsset(
		uint256 _listingId,
		uint256 _itemAmount
	) external whenListingOperating payable {
		Listing storage listing = listings[_listingId];

		require(listing.availableQuantity >= _itemAmount, "MM: Out of stock!");

		require(
			listing.expiredAt == 0 ||
			(block.timestamp >= listing.startedAt &&
			block.timestamp <= listing.expiredAt),
			"MM: Listing was not available!"
		);
		require(listing.status, "MM: Listing was canceled!");
		require(listing.seller != msg.sender, "MM: You could NOT buy from yourself!");
		bool isBNB = (address(listing.paymentToken) == address(0));

		if (isBNB) {
			require(msg.value == listing.unitPrice * _itemAmount, "MM: You must pay with the right price!");
		} else {
			require(msg.value == 0, "MM: This listing don't accept BNB!");
		}


		uint256 totalPrice =  listing.unitPrice * _itemAmount;
		uint256 marketCut = marketFee * totalPrice / ONE_HUNDRED_PERCENT;
		marketTreasury[listing.paymentToken] += marketCut;
		listing.availableQuantity -= _itemAmount;

		// Transfer NFT assets
		_transferAsset(address(this), msg.sender, listing.nftAddress, listing.nftId, _itemAmount, "0x");

		if (!isBNB) {
			// Transfer token to pool, only on other token because BNB already sent by call value
			IERC20(listing.paymentToken).safeTransferFrom(msg.sender, address(this), totalPrice);
		}

		// Transfer payment, check payment token logic inside
		uint256 netPrice = totalPrice - marketCut;


		_transfer(listing.paymentToken, payable(listing.seller), netPrice);

		emit AssetBought(msg.sender, _listingId, _itemAmount);
	}

	/**
	 * @dev User cancel listing
	 * @param _listingId ID of listing items
	 * emit {CancelList} event
	 */
	function cancelListing(uint256 _listingId) external {
		Listing storage listing = listings[_listingId];
		require(listing.seller == msg.sender, "MM: You was NOT the seller!");
		require(listing.availableQuantity > 0 , "MM: This listing was done!");
		require(listing.status, "MM: This listing already canceled!");

		listing.status = false;

		_transferAsset(address(this), msg.sender, listing.nftAddress, listing.nftId, listing.availableQuantity, "0x");
		emit ListingCanceled(_listingId);
	}

	function createOffer(uint256 _listingId, uint256 _proposedAmount, uint256 _proposedPrice) payable whenOfferOperating external {
		// Offer memory offer = offers[];
		Listing storage listing = listings[_listingId];

		require(listing.availableQuantity > _proposedAmount, "MM: Out of stock!");

		require(
			listing.expiredAt == 0 ||
			(block.timestamp >= listing.startedAt &&
			block.timestamp <= listing.expiredAt),
			"MM: Listing was not available!"
		);
		require(listing.status, "MM: Listing was canceled!");
		uint256 _offerId = offers.length;
		uint256 totalAmount = _proposedPrice * _proposedAmount;
		if (listing.paymentToken == address(0)) {
			require(totalAmount == msg.value, "Not enough to pay!");
		} else {
			IERC20(listing.paymentToken).safeTransferFrom(msg.sender, address(this), totalAmount);
		}

		offers.push(
			Offer(
				true,
				msg.sender,
				_listingId,
				_proposedAmount,
				_proposedPrice
			)
		);
		emit OfferCreated(_offerId, msg.sender, _listingId, _proposedAmount, _proposedPrice);
	}

	function acceptOffer(uint256 _offerId) external whenOfferOperating {
		Offer storage offer = offers[_offerId];
		Listing storage listing = listings[offer.listingId];
		require(offer.status, "MM: Offer was canceled!");
		require(offer.amount > 0, "MM: Offer was accepted");

		require(listing.availableQuantity >= offer.amount, "MM: Out of stock!");
		require(
			listing.expiredAt == 0 ||
			(block.timestamp >= listing.startedAt &&
			block.timestamp <= listing.expiredAt),
			"MM: Listing was not available!"
		);
		require(listing.status, "MM: Listing was canceled!");

		uint256 totalPrice =  offer.unitPrice * offer.amount;
		uint256 marketCut = marketFee * totalPrice / ONE_HUNDRED_PERCENT;
		marketTreasury[listing.paymentToken] += marketCut;
		listing.availableQuantity -= offer.amount;
		offer.amount = 0;
		// Transfer NFT assets
		_transferAsset(address(this), offer.creator, listing.nftAddress, listing.nftId, offer.amount, "0x");
		uint256 netPrice = totalPrice - marketCut;
		_transfer(listing.paymentToken, payable(listing.seller), netPrice);
		emit OfferAccepted(_offerId);
	}

	function cancelOffer(uint256 _offerId) external {
		Offer storage offer = offers[_offerId];
		Listing storage listing = listings[offer.listingId];
		require(offer.status, "MM: Offer was already canceled!");
		require(offer.amount > 0, "MM: Offer was accepted");
		uint256 refundAmount = offer.amount * offer.unitPrice;
		offer.status =false;
		_transfer(listing.paymentToken, payable(msg.sender), refundAmount);
		emit OfferCanceled(_offerId);
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
			require(amount_ == 1, "MM: ERC721 could NOT be fraud!");
			IERC721(nftAddress_).safeTransferFrom(from_, to_, nftId_, data_);
		}
	}
}