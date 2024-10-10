import json

def get_battleship_game_source():
    with open('contracts/BattleshipGameTestnet.sol', 'r') as f:
        return f.read()

def get_zen_token_source():
    with open('contracts/zenToken.sol', 'r') as f:
        return f.read()
    
def get_battleship_game_abi():
    with open('contracts/abis/BattleshipGameTestnetAbi.json', 'r') as f:
        return json.load(f)

def get_erc20_token_abi():
    with open('contracts/abis/erc20.json', 'r') as f:
        return json.load(f)