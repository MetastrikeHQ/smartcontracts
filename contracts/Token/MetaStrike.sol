// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaStrike is ERC20, Ownable {
	//Wednesday, December 15, 2021 9:30:00 PM GMT+07:00
	uint256 public startTime;
	uint256 public endTime;
	uint256 public maxAmount;
	address public LPAddress;
	bool setup;

    constructor() ERC20("MetaStrike", "MTS") {
        _mint(msg.sender, 565000000 * 10 ** decimals());
    }

	function setupListing(address _LPAddress, uint256 _maxAmount, uint256 _startTime) external onlyOwner {
		require(!setup, "Listing already setup");
		LPAddress = _LPAddress;
		maxAmount = _maxAmount;
		startTime = _startTime;
		endTime = startTime + 200;
	}

	
	/**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
	function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
		if (msg.sender == LPAddress && block.timestamp >= startTime && block.timestamp <= endTime) {
			require(amount <= maxAmount, 'MetaStrike: maxAmount exceed listing!');
		}

		_transfer(_msgSender(), recipient, amount);
		return true;
	}
}