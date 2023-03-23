// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface VerichainsNetRegistry {
    function randomService(uint256 key) external returns(VerichainsNetRandomService);
}
interface VerichainsNetRandomService {
    function random() external returns(uint256);
}

contract MetaLuckyNumber is Ownable {

    uint256 constant RANDOM_LEN = 24;
    uint256 constant RANDOM_PIECE = 9;
    uint256 constant TEN_HUNDRED = 10000;

    using SafeERC20 for IERC20;
    IERC20 public mtsERC20;
    uint256[24] public randomRate;
    uint256[9] public randomMax;
    uint256[24] public currentPiece;

    bool public getNumberOperating;
    bool public claimOperating;
    mapping (address => mapping (uint256 => uint256)) public userResults;
    mapping (address => uint256) public userClaimable;
    mapping (address => bool) public blacklist;

    uint256 constant randomKey = 0xc9821440a2c2cc97acac89148ac13927dead00238693487a9c84dfe89e28a284;
    address public randomRegistry;

    event GotRandomNumber(address user, uint256 randomNumber, uint256 result);
    event Claimed(address user,uint256 amt);

    constructor(address _mtsERC20, address _randomRegistry) {
        mtsERC20 = IERC20(_mtsERC20);
        randomRegistry = _randomRegistry;
        randomRate = [7,60,350,450,650,800,1000,1683,2000,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200];
        getNumberOperating = true;
        randomMax = [10,90,500,700,1000,1200,1500,2000,3000];
    }

    modifier whenGetNumberOperating() {
        require(getNumberOperating, "getLuckyNumber: paused");
        _;
    }

    function updateGetNumberOperating(bool newGet) external onlyOwner{
        getNumberOperating = newGet;
    }

    modifier whenClaimOperating() {
        require(claimOperating, "claim: paused");
        _;
    }

    function updateClaimOperating(bool newClaim) external onlyOwner{
        claimOperating = newClaim;
    }

    function getRandomNumber() whenGetNumberOperating public {
        require(msg.sender == tx.origin, "Nope!");
        require(!blacklist[msg.sender]);
        uint256 rnd;
        uint256 result;
        uint256 randomNumber = VerichainsNetRegistry(randomRegistry).randomService(MetaLuckyNumber.randomKey).random();
        rnd = randomNumber % TEN_HUNDRED;
        for(uint256 i=0; i<RANDOM_LEN; i++) {
            if(rnd < randomRate[i]){
                if(i < RANDOM_PIECE && currentPiece[i]>= randomMax[i]){
                    i += RANDOM_PIECE;
                }
                currentPiece[i] +=1;
                userResults[msg.sender][i] += 1;
                result = i;
                break;
            }
            else{
                rnd -= randomRate[i];
            }
        }
        emit GotRandomNumber(msg.sender, randomNumber, result);
    }

    function claim() whenClaimOperating public {
        require(userClaimable[msg.sender] > 0, "You have already claimed or no reward!");
        mtsERC20.safeTransfer(msg.sender, userClaimable[msg.sender]);
        emit Claimed(msg.sender, userClaimable[msg.sender]);
        userClaimable[msg.sender] = 0;
    }

    function setUpClaim(address[] calldata _user, uint256[] calldata _amt) external onlyOwner {
        require(_user.length == _amt.length, "setUpClaim mismatched!");
			for (uint256 i = 0; i < _user.length; i ++ ) {
				userClaimable[_user[i]] = _amt[i];
			}
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

    function withdraw(address _to,uint256 _amt) external onlyOwner {
        mtsERC20.safeTransfer(_to, _amt);
    }

}