// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BattleshipGame {
    uint8 constant gridSize = 100;
    uint8 constant totalShips = 249;
    uint8 constant shipLength = 3;
    uint256 constant HIT_REWARD = 1 * 10**18; // 1 ZEN token (18 decimals)
    uint256 constant SINK_REWARD = 3 * 10**18; // 3 ZEN tokens
    uint256 constant FINAL_SINK_REWARD = 20 * 10**18; // 20 ZEN tokens

    struct Position {
        uint8 x;
        uint8 y;
    }

    struct Ship {
        Position start;
        bool[shipLength] hits;
    }

    Ship[totalShips] public ships;
    mapping(uint16 => uint8) private positionToShipIndex;
    mapping(uint16 => bool) public hits;
    mapping(uint16 => bool) private misses;
    uint256 private seed;
    uint256 private nonce = 0;
    bool[totalShips] public graveyard;
    uint8 public sunkShipsCount;
    bool public gameOver;
    Position[] private allHits;
    Position[] private allMisses;

    mapping(address => uint16) private playerHits;
    mapping(address => uint16) private playerSinks;
    address private lastSunkShipPlayer;
    uint256 private totalHits;
    uint256 public totalZENAllocated; // Track total ZEN tokens allocated

    IERC20 public rewardToken;

    event GameOver(address winner, uint256 totalZENAllocated);
    event HitFeedback(address indexed user, uint8[2] guessedCoords, bool success, bool sunk, Position[] allHits, Position[] allMisses, bool[totalShips] graveyard, uint256 totalZENAllocated, uint256 zenTransferred);

    constructor(address tokenAddress) {
        rewardToken = IERC20(tokenAddress);
        seed = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender)));
        generatePositions();
    }

    function generatePositions() private {
        uint8 index = 0;
        while (index < totalShips) {
            uint256 hash = uint256(keccak256(abi.encodePacked(seed, nonce)));
            for (uint8 i = 0; i < 36 && index < totalShips; i++) {
                uint8 x = uint8(hash & 0x7F) % gridSize;
                uint8 y = uint8((hash >> 7) & 0x7F) % gridSize;

                if (isPositionUniqueAndFits(x, y)) {
                    ships[index].start = Position(x, y);
                    for (uint8 j = 0; j < shipLength; j++) {
                        uint16 positionKey = packCoordinates(x + j, y);
                        positionToShipIndex[positionKey] = index + 1;
                    }
                    index++;
                }
                hash >>= 14;
            }
            nonce++;
        }
    }

    function isPositionUniqueAndFits(uint8 x, uint8 y) private view returns (bool) {
        if (x + shipLength > gridSize) return false;
        for (uint8 j = 0; j < shipLength; j++) {
            uint16 positionKey = packCoordinates(x + j, y);
            if (positionToShipIndex[positionKey] != 0) {
                return false;
            }
        }
        return true;
    }

    function packCoordinates(uint8 x, uint8 y) private pure returns (uint16) {
        return (uint16(x) << 8) | uint16(y);
    }

    function getShipPosition(uint8 shipIndex) public view returns (Position memory) {
        require(shipIndex - 1 < totalShips, 'Ship index out of bounds');
        return ships[shipIndex - 1].start;
    }

    function getAllShipPositions() public view returns (Ship[totalShips] memory) {
        return ships;
    }

    function getShipAtPosition(uint8 x, uint8 y) public view returns (uint8) {
        uint16 positionKey = packCoordinates(x, y);
        uint8 shipIndex = positionToShipIndex[positionKey];
        require(shipIndex != 0, 'No ship at given position');
        return shipIndex;
    }

    function hit(uint8 x, uint8 y) public payable {
        require(!gameOver, 'Game is over, no more hits accepted');
        require(msg.value == 0.00443 ether, 'Incorrect fee amount');
        uint16 positionKey = packCoordinates(x, y);
        require(!hits[positionKey], 'Cell already hit');
        _processHit(msg.sender, x, y);
    }

    function _processHit(address player, uint8 x, uint8 y) private {
        uint16 positionKey = packCoordinates(x, y);
        require(!hits[positionKey], 'Cell already hit');
        bool success;
        bool sunk;
        uint256 zenTransferred = 0;

        hits[positionKey] = true;
        totalHits++;
        playerHits[player]++;

        uint8 shipIndex = positionToShipIndex[positionKey];
        if (shipIndex != 0) {
            shipIndex--;
            success = true;
            Ship storage ship = ships[shipIndex];
            uint8 hitIndex = x - ship.start.x;
            ship.hits[hitIndex] = true;
            allHits.push(Position(x, y));

            bool allHit = true;
            for (uint8 i = 0; i < shipLength; i++) {
                if (!ship.hits[i]) {
                    allHit = false;
                    break;
                }
            }
            if (allHit) {
                sunk = true;
                graveyard[shipIndex] = true;
                sunkShipsCount++;
                playerSinks[player]++;
                if (sunkShipsCount == totalShips) {
                    gameOver = true;
                    lastSunkShipPlayer = player;
                    zenTransferred = FINAL_SINK_REWARD;
                    emit GameOver(lastSunkShipPlayer, totalZENAllocated);
                } else {
                    zenTransferred = SINK_REWARD;
                }
            } else {
                zenTransferred = HIT_REWARD;
            }
        } else {
            success = false;
            misses[positionKey] = true;
            allMisses.push(Position(x, y));
        }

        if (zenTransferred > 0) {
            require(rewardToken.transfer(player, zenTransferred), "Token transfer failed");
            totalZENAllocated += zenTransferred;
        }

        emit HitFeedback(player, [x, y], success, sunk, allHits, allMisses, graveyard, totalZENAllocated, zenTransferred);
    }

    function isHit(uint8 x, uint8 y) public view returns (bool) {
        uint16 positionKey = packCoordinates(x, y);
        return hits[positionKey];
    }

    function isSunk(uint8 shipIndex) public view returns (bool) {
        require(shipIndex < totalShips, 'Ship index out of bounds');
        return graveyard[shipIndex];
    }

    function getHitsOnShip(uint8 shipIndex) public view returns (bool[shipLength] memory) {
        require(shipIndex < totalShips, 'Ship index out of bounds');
        return ships[shipIndex].hits;
    }

    function getGraveyard() public view returns (bool[totalShips] memory) {
        return graveyard;
    }

    function getAllHits() public view returns (Position[] memory) {
        return allHits;
    }

    function getAllMisses() public view returns (Position[] memory) {
        return allMisses;
    }

    function getPersonalStats() public view returns (uint16 personalHits, uint16 personalSinks) {
        personalHits = playerHits[msg.sender];
        personalSinks = playerSinks[msg.sender];
        return (personalHits, personalSinks);
    }

    function getZenTokenBalance() public view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }
}
