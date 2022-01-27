// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetaFixedStaking is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public mtsERC20;

    struct PoolInfo {
        uint256 hardCap;
        uint256 staking;
        uint256 fixedRate;
        uint256 startDate;
        uint256 duration;
        uint256 maxStake;
    }

    mapping(uint256 => PoolInfo) public poolsInfo;
    mapping(address => bool) public participant;

    uint256 constant internal PER_MILE = 1000;

    event Staking(address user, uint256 pid, uint256 amount);
    event Unstaking(address user, uint256 poolId, uint256 staked, uint256 claiming, uint256 reward);

    mapping (address => mapping (uint256 => uint256)) public staking;

    constructor (address _mtsERC20) {
        mtsERC20 = IERC20(_mtsERC20);
    }

    function addPool(uint256 _pid, uint256 _hardCap, uint256 _fixedRate, uint256 _startDate, uint256 _duration, uint256 _maxStake) external onlyOwner {
        poolsInfo[_pid] = PoolInfo(_hardCap, 0, _fixedRate, _startDate, _duration, _maxStake);
    }

    function stake(uint256 _pid, uint256 _amount) public {
        PoolInfo storage poolInfo = poolsInfo[_pid];
        require(poolInfo.staking + _amount <= poolInfo.hardCap, "MetaFixedStaking: The Pool was fulfilled!");
        require(_amount <= poolInfo.maxStake, "MetaFixedStaking: The amount should be less than the maximum!");
        require(block.timestamp < poolInfo.startDate, "MetaFixedStaking: This pool was locked, you can NOT deposit!");
        mtsERC20.safeTransferFrom(msg.sender, address(this), _amount);
        staking[msg.sender][_pid] += _amount;
        poolInfo.staking += _amount;
        participant[msg.sender] = true;
        emit Staking(msg.sender, _pid, _amount);
    }

    function unstake(uint256 _pid) public {
        PoolInfo storage poolInfo = poolsInfo[_pid];
        uint256 claiming;
        uint256 reward;
        uint256 staked = staking[msg.sender][_pid];
        require(staking[msg.sender][_pid] > 0, "MetaFixedStaking: Are you sure you coming here before?");
        require (block.timestamp >= poolInfo.startDate + poolInfo.duration, "MetaFixedStaking: You can NOT unstake before duration end!");
        reward = staked * poolInfo.fixedRate / PER_MILE;
        claiming = reward + staked;
        poolInfo.staking -= staking[msg.sender][_pid];
        staking[msg.sender][_pid] = 0;
        mtsERC20.safeTransfer(msg.sender, claiming);
        emit Unstaking(msg.sender, _pid, staked, claiming, reward);
    }
}