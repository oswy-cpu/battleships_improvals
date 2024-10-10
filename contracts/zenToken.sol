// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract ZENToken is ERC20, Ownable {
    // Define a mapping to store admin addresses
    mapping(address => bool) public admins;

    // Event for adding and removing admins
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);

    constructor() ERC20("ZEN Token", "ZEN") Ownable(msg.sender) {
        // The contract deployer is set as the initial admin
        admins[msg.sender] = true;
        // Optionally, mint some initial tokens to the owner
        // _mint(msg.sender, 1000 * 10 ** decimals());
    }

    // Modifier to restrict function access to admins only
    modifier onlyAdmin() {
        require(admins[msg.sender], "Caller is not an admin");
        _;
    }

    // Function to mint new tokens, only accessible by admins
    function mint(address to, uint256 amount) external onlyAdmin {
        _mint(to, amount);
    }

    // Function to add a new admin, only accessible by the owner
    function addAdmin(address newAdmin) external onlyOwner {
        require(!admins[newAdmin], "Address is already an admin");
        admins[newAdmin] = true;
        emit AdminAdded(newAdmin);
    }

    // Function to remove an admin, only accessible by the owner
    function removeAdmin(address admin) external onlyOwner {
        require(admins[admin], "Address is not an admin");
        admins[admin] = false;
        emit AdminRemoved(admin);
    }
}
