// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MetaVerifier.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC20Mintable is IERC20 {
    function mint(address user, uint256 amount) external;
}

interface IERC1155Mintable is IERC1155 {
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;
}

contract MetaTokenPortal is MetaVerifier, Ownable {

    using SafeERC20 for IERC20;
    IERC20 public mtsERC20;
    address public tokenMts;
    address public tokenMtt;

    mapping(address => uint256) public nonces;

    mapping(uint256 => uint256) public totalMtsByDay;
    mapping(uint256 => uint256) public totalMttByDay;

    uint256 public limitMtsByDay;
    uint256 public limitMttByDay;

    uint256 public constant ONE_DAY = 24 hours;

    event SignerUpdated(address newSigner);
    event TokenMtsUpdated(address newToken);
    event TokenMttUpdated(address newToken);
    event MtsClaimed(address indexed user, uint256 amount, uint256 nonce);
    event MttClaimed(address indexed user, uint256 amount, uint256 nonce);
    event TokenDeposited(address indexed tokenAddress, address indexed user, uint256 amount);
    event LimitUpdated(uint256 newLimitTokenMTS, uint256 newLimitTokenMTT);

    constructor(address _signer, address _tokenMts, address _tokenMtt) MetaVerifier(_signer) {
        tokenMts = _tokenMts;
        tokenMtt = _tokenMtt;
        mtsERC20 = IERC20(_tokenMts);
    }

    function updateSigner(address _newSigner) external onlyOwner {
        signer = _newSigner;
        emit SignerUpdated(_newSigner);
    }

    function updateTokenMts(address _newToken) external onlyOwner {
        tokenMts = _newToken;
        emit TokenMtsUpdated(_newToken);
    }

    function updateTokenMtt(address _newToken) external onlyOwner {
        tokenMtt = _newToken;
        emit TokenMttUpdated(_newToken);
    }

    function updateLimit(uint256 _newLimitMts, uint256 _newLimitMtt) external onlyOwner {
        // 0 mean no limit
        limitMtsByDay = _newLimitMts;
        limitMttByDay = _newLimitMtt;
        emit LimitUpdated(_newLimitMts, _newLimitMtt);
    }

    /**
     * @dev Function to return the message hash that will be signed by the signer
     */
    function getAmountMessageHash(
        address account,
        uint256 amount,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), account, amount, nonce));
    }

    /**
     * @dev Function to return the message hash that will be signed by the signer
     */
    function getTokenAmountMessageHash(
        address account,
        address token,
        uint256 amount,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), account, token, amount, nonce));
    }


    function depositMts(uint256 amount) external {
        IERC20(tokenMts).transferFrom(msg.sender, address(this), amount);
        emit TokenDeposited(tokenMts, msg.sender, amount);
    }

    function depositMtt(uint256 amount) external {
        IERC20(tokenMtt).transferFrom(msg.sender, address(this), amount);
        emit TokenDeposited(tokenMtt, msg.sender, amount);
    }

    function claimMTS(uint256 amount, bytes calldata signature) external {
        require((amount + totalMtsByDay[block.timestamp / ONE_DAY] <= limitMtsByDay) || limitMtsByDay == 0, "Reached Limit Per Day!");
        uint256 currentNonce = nonces[msg.sender]++;
        bytes32 messageHash = getTokenAmountMessageHash(msg.sender, tokenMts, amount, currentNonce);
        require(verify(messageHash, signature), "Invalid Signature");
        totalMtsByDay[block.timestamp / ONE_DAY] += amount;
        IERC20Mintable(tokenMts).transfer(msg.sender, amount);
        emit MtsClaimed(msg.sender, amount, currentNonce);
    }

    function claimMTT(uint256 amount, bytes calldata signature) external {
        require((amount + totalMttByDay[block.timestamp / ONE_DAY] <= limitMttByDay) || limitMttByDay == 0, "Reached Limit Per Day!");
        uint256 currentNonce = nonces[msg.sender]++;
        bytes32 messageHash = getTokenAmountMessageHash(msg.sender, tokenMtt, amount, currentNonce);
        require(verify(messageHash, signature), "Invalid Signature");
        totalMttByDay[block.timestamp / ONE_DAY] += amount;
        IERC20Mintable(tokenMtt).mint(msg.sender, amount);
        emit MttClaimed(msg.sender, amount, currentNonce);
    }

    function withdraw(address _to,uint256 _amt) external onlyOwner {
        mtsERC20.safeTransfer(_to, _amt);
    }

}