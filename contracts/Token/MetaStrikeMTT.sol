// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IBPContract {
    function protect(address sender, address receiver, uint256 amount) external;
}

contract MetaStrikeMTT is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    IBPContract public bpContract;

    bool public bpEnabled;
    bool public bpDisabledForever;
    

    constructor() ERC20("Metastrike", "MTT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function checkBlacklisted(address _user) view external returns(bool) {
        return blacklisted[_user];
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function blackList(address _evil, bool _black) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklisted[_evil] = _black;
    }

    function batchBlackList(address[] calldata _evils, bool[] calldata _blacks) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_blacks.length == 1) {
            for (uint256 i = 0; i < _evils.length; i++) {
                blacklisted[_evils[i]] = _blacks[0];
            }
        } else {
            require(_evils.length == _blacks.length, "MTT: Input Format Mismatch!");
            for (uint256 i = 0; i < _evils.length; i++) {
                blacklisted[_evils[i]] = _blacks[i];
            }
        }
    }

    function setBPContract(address addr)
        public
        onlyOwner
    {
        require(addr != address(0), "BP adress cannot be 0x0");

        bpContract = IBPContract(addr);
    }

    function setBPEnabled(bool enabled)
        public
        onlyOwner
    {
        bpEnabled = enabled;
    }

    function setBPDisableForever()
        public
        onlyOwner
    {
        require(!bpDisabledForever, "Bot protection disabled");

        bpDisabledForever = true;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        if (bpEnabled && !bpDisabledForever) {
            bpContract.protect(from, to, amount);
        }
        require(!blacklisted[from], "MTT: This sender was blacklisted!");
        require(!blacklisted[to], "MTT: This recipient was blacklisted!");
        super._beforeTokenTransfer(from, to, amount);
    }
}
