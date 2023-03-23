// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @custom:security-contact security@metastrike.io
contract MetaMetal is ERC1155, AccessControl, Pausable, ERC1155Burnable, ERC1155Supply {
    using SafeERC20 for IERC20;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct AcquireInfo {
        uint256 metalId;
        address paymentToken;
        uint256 price;
        uint256 totalAmount;
        uint256 startDate;
        uint256 endDate;
        uint256 acquired;
    }

    struct MetalInfo {
        uint256 kind;
        uint256 level;
        uint256 point;
        uint256 percentage;
    }

    mapping (uint256 => MetalInfo) public metals;

    mapping (uint256 => AcquireInfo) public acquireInfo;

    uint256 public totalMetalSale;

    event Acquired(address acquirer, uint256 acquireId, uint256 metalId, uint256 amount);

    string public constant name = "Metastrike Metal";
    string public constant symbol = "MSM";

    constructor() ERC1155("https://resource.metastrike.io/metal/{id}.json") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function getMetalInfo(uint256 id) public view returns (uint256, uint256) {
        return (metals[id].point, metals[id].percentage);
    }

    function setURI(string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setupMetal(uint256 metalId, uint256 _kind, uint256 _level, uint256 _point, uint256 _percentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_point > 0, "Metal could be zero point!");
        metals[metalId] = MetalInfo (_kind, _level, _point, _percentage);
    }

    function setupAcquire(uint256 _acquireId, uint256 _metalId, address _paymentToken, uint256 _price, uint256 _totalAmount, uint256 _startDate, uint256 _endDate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 acquired = acquireInfo[_acquireId].acquired;
        acquireInfo[_acquireId] = AcquireInfo(_metalId, _paymentToken, _price, _totalAmount, _startDate, _endDate, acquired);
    }

    function acquire(uint256 _acquireId, uint256 _amount, bytes memory data) public {
        AcquireInfo storage acquiring = acquireInfo[_acquireId];
        require(acquiring.acquired + _amount <= acquiring.totalAmount, "Insufficient Amount!");
        require(acquiring.startDate <= block.timestamp && block.timestamp <= acquiring.endDate, "Acquiring not available!");
        uint256 totalPrice = acquiring.price * _amount;
        IERC20(acquiring.paymentToken).safeTransferFrom(msg.sender, address(this), totalPrice);
        totalMetalSale += totalPrice;
        acquiring.acquired += _amount;
        _mint(msg.sender, acquiring.metalId, _amount, data);
        emit Acquired(msg.sender, _acquireId, acquiring.metalId, _amount);
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
        require(metals[id].point > 0, "This metal was not available!");
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}