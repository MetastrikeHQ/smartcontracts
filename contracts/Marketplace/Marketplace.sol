// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./HasSignature.sol";

contract MetaMarketplace is Ownable, HasSignature {
    using SafeERC20 for IERC20;

    // Supported payment token WETH & list of authorized ERC20
    mapping(address => bool) public paymentTokens;
    mapping(bytes => bool) public usedSignatures;

    // Address to receive transaction fee
    address public feeToAddress;
    uint256 public transactionFee;

    // Events
    event MatchTransaction(
        uint256 indexed tokenId,
        address contractAddress,
        uint256 price,
        address paymentToken,
        address seller,
        address buyer,
        uint256 feeInWei
    );

    constructor(address _feeCollector, address _paymentToken, uint256 _feePercent) {
        feeToAddress = _feeCollector;
        transactionFee = _feePercent; // 0.5% will be 5
        paymentTokens[_paymentToken] = true;
    }

    function setFeeToAddress(address _feeToAddress) public onlyOwner {
        feeToAddress = _feeToAddress;
    }

    function setTransactionFee(uint256 _transactionFee) public onlyOwner {
        transactionFee = _transactionFee;
    }

    function setPaymentTokens(address[] calldata _paymentTokens)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _paymentTokens.length; i++) {
            if (paymentTokens[_paymentTokens[i]] == true) {
                continue;
            }

            paymentTokens[_paymentTokens[i]] = true;
        }
    }

    function removePaymentTokens(address[] calldata _removedPaymentTokens)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _removedPaymentTokens.length; i++) {
            paymentTokens[_removedPaymentTokens[i]] = false;
        }
    }

    function matchTransaction(
        address[3] calldata addresses,
        uint256[3] calldata values,
        bytes calldata signature
    ) external returns (bool) {
        require(
            paymentTokens[addresses[2]] == true,
            "Marketplace: invalid payment method"
        );

        require(
            !usedSignatures[signature],
            "Marketplace: signature used. please send another transaction with new signature"
        );

        bytes32 criteriaMessageHash = getMessageHash(
            addresses[1],
            values[0],
            addresses[2],
            values[1],
            values[2]
        );

        bytes32 ethSignedMessageHash = getEthSignedMessageHash(
            criteriaMessageHash
        );

        require(
            recoverSigner(ethSignedMessageHash, signature) == addresses[0],
            "Marketplace: invalid seller signature"
        );

        // check current ownership
        IERC721 nft = IERC721(addresses[1]);
        require(
            nft.ownerOf(values[0]) == addresses[0],
            "Marketplace: seller is not owner of this item now"
        );

        // Check payment approval and buyer balance
        IERC20 paymentContract = IERC20(addresses[2]);
        require(
            paymentContract.balanceOf(_msgSender()) >= values[1],
            "Marketplace: buyer doesn't have enough token to buy this item"
        );
        require(
            paymentContract.allowance(_msgSender(), address(this)) >= values[1],
            "Marketplace: buyer doesn't approve marketplace to spend payment amount"
        );

        // We divide by 10000 to support decimal value such as 5% => 50 / 1000
        uint256 fee = transactionFee * values[1] / 1000;
        uint256 payToSellerAmount = values[1] - fee;

        // transfer money to seller
        paymentContract.safeTransferFrom(
            _msgSender(),
            addresses[0],
            payToSellerAmount
        );

        // transfer fee to address
        if (fee > 0) {
            paymentContract.safeTransferFrom(_msgSender(), feeToAddress, fee);
        }

        // transfer item to buyer
        nft.safeTransferFrom(addresses[0], _msgSender(), values[0]);

        usedSignatures[signature] = true;
        // emit sale event
        emitEvent(addresses, values, fee);
        return true;
    }

    function emitEvent(
        address[3] calldata addresses,
        uint256[3] calldata values,
        uint256 feeInWei
    ) internal {
        emit MatchTransaction(
            values[0],
            addresses[1],
            values[1],
            addresses[2],
            addresses[0],
            _msgSender(),
            feeInWei
        );
    }

    function getMessageHash(
        address _nftAddress,
        uint256 _tokenId,
        address _paymentErc20,
        uint256 _price,
        uint256 _saltNonce
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _nftAddress,
                    _tokenId,
                    _paymentErc20,
                    _price,
                    _saltNonce
                )
            );
    }
}