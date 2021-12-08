// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaVesting is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public mtsERC20;

    struct VestingStrategy {
        uint256 tge;
        uint256 cliff;
        uint256 linearDuration;
    }

    struct VestingInfo {
        uint256 amount;
        uint256 claimed;
        uint256 lastClaim;
    }

    uint256 public tgeTime;

    mapping (uint256 => VestingStrategy) public vestingStrategy;
    mapping (address => mapping (uint256 => VestingInfo)) public userToVesting;
    mapping (address => uint256[]) public userVesting;

    constructor (address _mtsERC20, uint256 _tgeTime) {
        mtsERC20 = IERC20(_mtsERC20);
        tgeTime = _tgeTime;
    }

    function setupVestingStrategy(uint256 _id, uint256 _tgePercent, uint256 _cliffSecs, uint256 _linearSecs) external onlyOwner {
        vestingStrategy[_id] = VestingStrategy(_tgePercent, _cliffSecs, _linearSecs);
    }

    function setupVestingUser(uint256 _strategyId, uint256 _amount, address[] calldata _users) external onlyOwner{
        for(uint256 i =0; i < _users.length; i++ ) {
            userToVesting[_users[i]][_strategyId].amount += _amount;
            userToVesting[_users[i]][_strategyId].claimed = 0;
            userToVesting[_users[i]][_strategyId].lastClaim = tgeTime;

        }
    }

    function claimable(address _user, uint256 _strategyId) public view returns (uint256) {
        VestingInfo memory userInfo = userToVesting[_user][_strategyId];
        VestingStrategy memory vestingInfo = vestingStrategy[_strategyId];

        uint256 _claimTge = vestingInfo.tge * userInfo.amount / 1000;
        uint256 _amountAfterTge = userInfo.amount - _claimTge;
        uint256 _timeSpent;
        uint256 _claiming;
        if (userInfo.claimed < _claimTge) {
            _claiming = _claimTge;
        }
        if (tgeTime + vestingInfo.cliff < block.timestamp) {
            if (tgeTime + vestingInfo.cliff < userInfo.lastClaim) {
                _timeSpent = block.timestamp - (tgeTime + vestingInfo.cliff);
            } else {
                _timeSpent = block.timestamp - userInfo.lastClaim;
            }
        }
        _claiming += _timeSpent * _amountAfterTge / vestingInfo.linearDuration;
        if (_claiming > userInfo.amount - userInfo.claimed) {
            _claiming = userInfo.amount - userInfo.claimed;
        }
        return _claiming;
    }

    function claim(uint256 _strategyId) public {
        VestingInfo storage userInfo = userToVesting[msg.sender][_strategyId];
        VestingStrategy storage vestingInfo = vestingStrategy[_strategyId];
        require(userInfo.amount > 0, "MetaVesting: You don't have allocation for this type!");
        require(userInfo.claimed < userInfo.amount, "MetaVesting: You already received fully your allocation!");
        uint256 claiming;
        uint256 claimTge = vestingInfo.tge * userInfo.amount / 1000;
        uint256 amountAfterTge = userInfo.amount - claimTge;
        uint256 timeSpent;
        if (userInfo.claimed < claimTge) {
            claiming = claimTge;
        }

        if (tgeTime + vestingInfo.cliff < block.timestamp) {
            if (tgeTime + vestingInfo.cliff < userInfo.lastClaim) {
                timeSpent = block.timestamp - (tgeTime + vestingInfo.cliff);
            } else {
                timeSpent = block.timestamp - userInfo.lastClaim;
            }
        }

        claiming += timeSpent * amountAfterTge / vestingInfo.linearDuration;

        if (claiming > userInfo.amount - userInfo.claimed) {
            claiming = userInfo.amount - userInfo.claimed;
        }

        userInfo.claimed += claiming;
        userInfo.lastClaim = block.timestamp;

        require(claiming > 0, "MetaVesting: We already vested all tokens!");
        mtsERC20.safeTransfer(msg.sender, claiming);
    }

    function withdraw(address _to) external onlyOwner {
        mtsERC20.safeTransfer(_to, mtsERC20.balanceOf(address(this)));
    }

}