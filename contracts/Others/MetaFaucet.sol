// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MetaFaucet is Ownable {

    uint256 public constant ONE_DAY = 24 hours;

    using SafeERC20 for IERC20;
    IERC20 public mtsERC20;
    IERC20 public tBusd;
    uint public mtsAmt;
    uint public bUsdAmt;

    bool public faucetClaimOperating;
    mapping (address => uint256) public userLastClaim;
    mapping (address => bool) public blacklist;

    event GotRandomNumber(address user, uint256 randomNumber, uint256 result);
    event FaucetClaimed(address user,uint256 amt);

    constructor(address _mtsERC20, address _tBusd) {
        mtsERC20 = IERC20(_mtsERC20);
        tBusd = IERC20(_tBusd);
        faucetClaimOperating = true;
    }


    modifier whenFaucetClaimOperating() {
        require(faucetClaimOperating, "FaucetClaim: paused");
        _;
    }

    function updateFaucetClaimOperating(bool newClaim) external onlyOwner{
        faucetClaimOperating = newClaim;
    }


    function claimFaucet() whenFaucetClaimOperating public {
        require(!blacklist[msg.sender],"You are blocked");
        //require(userLastClaim[msg.sender] + ONE_DAY < block.timestamp || userLastClaim[msg.sender] == 0 , "You cannot claim more than 1 time per day");
        userLastClaim[msg.sender] = block.timestamp;
        mtsERC20.safeTransfer(msg.sender, mtsAmt);
        tBusd.safeTransfer(msg.sender, bUsdAmt);
        emit FaucetClaimed(msg.sender, block.timestamp);
    }

    function setUpFaucetClaim(uint _mtsAmt, uint _bUsdAmt) external onlyOwner {
        mtsAmt = _mtsAmt;
        bUsdAmt = _bUsdAmt;
    }

    function setupBlacklist(address[] calldata _addressB, bool[] calldata _bs) external onlyOwner {
		if (_bs.length == 1) {
			for (uint256 i = 0; i < _addressB.length; i ++ ) {
				blacklist[_addressB[i]] = _bs[0];
			}
		} else {
			require(_addressB.length == _bs.length, "SetupBlacklist mismatched!");
			for (uint256 i = 0; i < _addressB.length; i ++ ) {
				blacklist[_addressB[i]] = _bs[i];
			}
		}
	}

    function withdrawMts(address _to,uint256 _amt) external onlyOwner {
        mtsERC20.safeTransfer(_to, _amt);
    }

    function withdrawBusd(address _to,uint256 _amt) external onlyOwner {
        tBusd.safeTransfer(_to, _amt);
    }

}