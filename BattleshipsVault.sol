// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./BattleshipsGame.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vault is Ownable {
    IERC20 public hitToken;
    BattleshipGame public BattleshipsGame;
    uint256 public exchangeRate = 0.0443 ether; // 2 HIT = 0.0443 ETH

    mapping(address => bool) public admins; // Admin role mapping

    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event HitTokensReceived(address indexed user, uint256 amount, uint8 x, uint8 y);
    event ExchangeExecuted(address indexed user, uint256 hitAmount, uint256 ethAmount);
    event ExchangeRateChanged(uint256 newRate);
    event HitTokensRequested(address indexed receiver, uint256 amount);

    constructor(address _hitTokenAddress, address _battleshipGameAddress) Ownable(msg.sender) {
        hitToken = IERC20(_hitTokenAddress);
        BattleshipsGame = BattleshipGame(_battleshipGameAddress);
    }

    // Modifier to restrict function access to only admins and the owner
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner(), "Vault: Not an admin or owner");
        _;
    }

    function executeHitWithToken(uint8 x, uint8 y) public {
        // Step 1: Ensure the game is not over
        require(!BattleshipsGame.gameOver(), 'Vault: Game is over, no more hits accepted');

        // Step 2: Check if the cell has already been hit
        require(!BattleshipsGame.isHit(x, y), 'Vault: Cell already hit');

        // Step 3: Transfer HIT tokens from user to Vault
        require(hitToken.transferFrom(msg.sender, address(this), 2 * 10**18), 'Vault: Token transfer failed');

        // Step 4: Convert HIT to ETH
        uint256 ethAmount = (2 * 10**18 * exchangeRate) / (2 * 10**18); // Exchange rate is 2 HIT = 0.0443 ETH
        require(address(this).balance >= ethAmount, "Vault: Insufficient ETH");

        // Step 5: Call BattleshipGame contract to process the hit
        BattleshipsGame.hitWithAddress{value: ethAmount}(msg.sender, x, y);

        emit HitTokensReceived(msg.sender, 2 * 10**18, x, y);
        emit ExchangeExecuted(msg.sender, 2 * 10**18, ethAmount);
    }

    function setBattleshipGameAddress(address _battleshipGame) external onlyOwner {
        BattleshipsGame = BattleshipGame(_battleshipGame);
    }

    function setHitTokenAddress(address _hitTokenAddress) external onlyOwner {
        hitToken = IERC20(_hitTokenAddress);
    }

    function setExchangeRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Vault: Exchange rate must be greater than 0");
        exchangeRate = newRate;
        emit ExchangeRateChanged(newRate);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Vault: Insufficient ETH");
        payable(owner()).transfer(amount);
    }

    // Add an admin
    function addAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Vault: Invalid admin address");
        admins[admin] = true;
        emit AdminAdded(admin);
    }

    // Remove an admin
    function removeAdmin(address admin) external onlyOwner {
        require(admins[admin], "Vault: Address is not an admin");
        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    // Admin can request HitTokens to be transferred to a specified address
    function requestHitToken(address receiver, uint256 amount) external onlyAdmin {
        require(hitToken.balanceOf(address(this)) >= amount, "Vault: Insufficient HIT tokens");
        hitToken.transfer(receiver, amount);
        emit HitTokensRequested(receiver, amount);
    }

    receive() external payable {}
}