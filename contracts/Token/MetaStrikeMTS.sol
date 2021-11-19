// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MetaStrike is ERC20, ERC20Burnable, Pausable, Ownable {
	uint256 public startTime;
	uint256 public endTime;
	uint256 public maxAmount;
	address public LPAddress;
	bool setup;
    mapping (address => bool) blacklisted;
    mapping (address => uint256) lastBuy;

    constructor() ERC20("MetaStrike", "MTS") {
        _mint(msg.sender, 565000000 * 10 ** decimals());
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