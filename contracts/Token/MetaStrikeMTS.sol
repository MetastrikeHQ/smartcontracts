// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

abstract contract TwoPhaseOwnable is Context {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "TwoPhaseOwnable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "TwoPhaseOwnable: new owner is the zero address");
        _pendingOwner = newOwner;
    }

    function acceptOwnership() public virtual {
        require(_msgSender() == pendingOwner(), "TwoPhaseOwnable: sender is not the next choosen one!");
        _setOwner(_pendingOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract MetaStrike is ERC20, ERC20Burnable, Pausable, TwoPhaseOwnable {
	uint256 public startTime;
	uint256 public endTime;
	uint256 public maxAmount;
	address public LPAddress;
	// bool setup;
    mapping (address => bool) blacklisted;
    mapping (address => uint256) lastBuy;

    constructor() ERC20("Metastrike", "MTS") {
        // _mint(msg.sender, 565000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

	function setupListing(address _LPAddress, uint256 _maxAmount, uint256 _startTime, uint256 _endTime) external onlyOwner {
		// require(!setup, "Listing already setup");
		LPAddress = _LPAddress;
		maxAmount = _maxAmount;
		startTime = _startTime;
		endTime = _endTime;
		// setup = true;
	}

    function blackList(address _evil, bool _black) external onlyOwner {
        blacklisted[_evil] = _black;
    }

    function batchBlackList(address[] memory _evil, bool[] memory _black) external onlyOwner {
        for (uint256 i = 0; i < _evil.length; i++) {
            blacklisted[_evil[i]] = _black[i];
        }
    }

	
	/**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     */
	function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
		if (msg.sender == LPAddress && block.timestamp >= startTime && block.timestamp <= endTime) {
			require(amount <= maxAmount, 'MTS: maxAmount exceed listing!');
            require(lastBuy[recipient] != block.number, "MTS: You already purchased in this block!");
            lastBuy[recipient] = block.number;
		}

		_transfer(_msgSender(), recipient, amount);
		return true;
	}

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        require(!blacklisted[from], "MTS: This sender was blacklisted!");
        require(!blacklisted[to], "MTS: This recipient was blacklisted!");
        super._beforeTokenTransfer(from, to, amount);
    }
}
