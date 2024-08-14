// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CustomToken is ERC20, Ownable, Pausable {
    uint256 public constant MAX_SUPPLY = 1000000 * 10**18; // 1,000,000 tokens with 18 decimals
    address public admin;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event AddressWhitelisted(address indexed _address);
    event AddressBlacklisted(address indexed _address);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not an admin");
        _;
    }

    modifier notBlacklisted(address _address) {
        require(!blacklist[_address], "Address is blacklisted");
        _;
    }

    constructor() ERC20("Hit1", "Hit1") Ownable(msg.sender){
        admin = msg.sender;
        whitelist[msg.sender] = true;
        emit AddressWhitelisted(msg.sender);
        _mint(msg.sender, MAX_SUPPLY);
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Invalid admin address");
        emit AdminChanged(admin, _newAdmin);
        admin = _newAdmin;
    }

    function addToWhitelist(address _address) external onlyAdmin {
        whitelist[_address] = true;
        emit AddressWhitelisted(_address);
    }

    function removeFromWhitelist(address _address) external onlyAdmin {
        whitelist[_address] = false;
    }

    function addToBlacklist(address _address) external onlyAdmin {
        blacklist[_address] = true;
        emit AddressBlacklisted(_address);
    }

    function removeFromBlacklist(address _address) external onlyAdmin {
        blacklist[_address] = false;
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }

    function withdrawEther() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        require(!paused(), "Token transfer while paused");
        require(!blacklist[from], "Sender is blacklisted");
        require(!blacklist[to], "Recipient is blacklisted");
        require(whitelist[to], "Recipient address is not whitelisted");

        // Call the parent _update to proceed with the actual transfer, mint, or burn
        super._update(from, to, value);
    }

    receive() external payable {}
}