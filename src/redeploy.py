import os
import time
from web3 import Web3
from web3.exceptions import InvalidAddress
from loguru import logger
from dotenv import load_dotenv, set_key
from solcx import compile_source, install_solc

from src.vercel import VercelAPI
from src.discord_status import send_status
from src.request_funds import request_funds
from src.utils import get_battleship_game_source, get_zen_token_source, get_erc20_token_abi, get_battleship_game_abi

install_solc('0.8.24')
logger.add('redeploy.log')

class redeployContracts:
    def __init__(self):
        load_dotenv(".env")

        self.rpc = os.getenv('TEN_RPC')
        self.token = os.getenv('DEPLOYER_TOKEN')
        self.deployer_key = os.getenv('DEPLOYER_PK')
        self.zen_address = os.getenv('ZEN_ADDRESS')
        self.battleships_address = os.getenv('BATTLESHIPS_ADDRESS')

        self.w3 = Web3(Web3.HTTPProvider(f'{self.rpc}{self.token}'))
        self.deployer_address = self.w3.to_checksum_address(self.w3.eth.account.from_key(self.deployer_key).address)
        self.faucet_manager = request_funds()
        self.vercelApi = VercelAPI()

        if not self.zen_address:
            self.zen_address = self.deploy_zen()
            self.update_env('ZEN_ADDRESS', self.zen_address)

        if not self.battleships_address:
            self.deploy_battleships()
            self.update_env('BATTLESHIPS_ADDRESS', self.battleships_address)

    def update_env(self, env_name, env_value):
        set_key('.env', env_name, env_value)

    def get_game_status(self) -> bool:
        try:
            status = self.w3.eth.contract(address=self.battleships_address, abi=get_battleship_game_abi()).functions.gameOver().call()
            return status
        except InvalidAddress: 
            send_status('error', 'Failed to get game status: the chain might be reset, contract address is invalid. Redeploying ZEN and Battleships')
            self.update_env('ZEN_ADDRESS', '')
            self.update_env('BATTLESHIPS_ADDRESS', '')
            return True
        except Exception as e: 
            send_status('error', f'Failed to get game status: the chain might be stuck. Retrying in 10 minutes')
            time.sleep(600)
            return self.get_game_status()

    def _get_deployer_balance(self):
        return self.w3.from_wei(self.w3.eth.get_balance(self.deployer_address), 'ether')
    
    def _get_test_wallet_zen_balance(self):
        return self.w3.from_wei(self.w3.eth.contract(address=self.zen_address, abi=get_erc20_token_abi()).functions.balanceOf(self.test_wallet).call(), 'ether')
    
    def _balance_conditions(self):
        return self._get_deployer_balance() < 0.5
    
    def _request_funding(self):
        if self._balance_conditions():
            logger.info(f"Deployer balance: {self._get_deployer_balance()} Requesting funds.")
            r = self.faucet_manager.request(self.deployer_address)
            if r:
                logger.info(f"Deployer balance: {self._get_deployer_balance()}")
                return True
            else:
                time.sleep(120)
                return self._request_funding()
        else: 
            logger.info(f"Deployer balance: {self._get_deployer_balance()}")
            return True
        
    def deploy_battleships(self) -> str:
        """
        Deploys the BattleshipGame contract on the TEN testnet with the specified ZEN address.
        This function requests funding from the faucet if the deployer's balance is less than 0.5 ETH.
        
        Returns:
            str: The contract address of the newly deployed BattleshipGame contract.
        """
        self._request_funding()

        
        compiled_sol = compile_source(get_battleship_game_source(), solc_version='0.8.24')
        contract_interface = compiled_sol['<stdin>:BattleshipGame']

        if not self.w3.is_connected():
            logger.error("Failed to connect to the TEN network")
            exit()
        
        BattleshipGame = self.w3.eth.contract(abi=contract_interface['abi'], bytecode=contract_interface['bin'])

        estimated_gas = BattleshipGame.constructor(self.zen_address).estimate_gas({
            'from': self.deployer_address,
        })
        
        transaction = BattleshipGame.constructor(self.zen_address).build_transaction({
            'chainId': self.w3.eth.chain_id,
            'gas': estimated_gas,
            'gasPrice': self.w3.to_wei('2', 'gwei'),
            'nonce': self.w3.eth.get_transaction_count(self.deployer_address),
        })

        signed_txn = self.w3.eth.account.sign_transaction(transaction, private_key=self.deployer_key)

        tx_hash = self.w3.eth.send_raw_transaction(signed_txn.raw_transaction)

        tx_receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300, poll_latency=1)

        self.battleships_address = tx_receipt.contractAddress

        self.update_env('BATTLESHIPS_ADDRESS', self.battleships_address)

        logger.success(f"Battleships Contract deployed to {self.battleships_address}")
        send_status('success', f"Battleships Contract deployed to {self.battleships_address}")

        self.prefund_battleships(self.battleships_address)

        self.vercelApi.update_battleships_env(self.battleships_address)
        self.vercelApi.redeploy()

        return
    
    def deploy_zen(self) -> str:
        """
        Deploys the ZEN token contract on the TEN testnet with the specified ZEN address.
        This function requests funding from the faucet if the deployer's balance is less than 0.5 ETH.
        
        Returns:
            str: The contract address of the newly deployed ZENToken contract.
        """
        self._request_funding()

        compiled_sol = compile_source(get_zen_token_source(), solc_version='0.8.24')
        contract_interface = compiled_sol['<stdin>:ZENToken']

        if not self.w3.is_connected():
            logger.error("Failed to connect to the TEN network")
            exit()
        
        zenToken = self.w3.eth.contract(abi=contract_interface['abi'], bytecode=contract_interface['bin'])

        estimated_gas = zenToken.constructor().estimate_gas({
            'from': self.deployer_address,
        })
        
        transaction = zenToken.constructor().build_transaction({
            'chainId': self.w3.eth.chain_id,
            'gas': estimated_gas,
            'gasPrice': self.w3.to_wei('2', 'gwei'),
            'nonce': self.w3.eth.get_transaction_count(self.deployer_address),
        })

        signed_txn = self.w3.eth.account.sign_transaction(transaction, private_key=self.deployer_key)

        tx_hash = self.w3.eth.send_raw_transaction(signed_txn.raw_transaction)

        tx_receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300, poll_latency=1)

        contract_address = tx_receipt.contractAddress

        logger.success(f"ZEN Contract deployed to {contract_address}")
        send_status('success', f"ZEN Contract deployed to {contract_address}")

        return contract_address
    
    def prefund_battleships(self, contract_address: str):
        contract = self.w3.eth.contract(address=self.zen_address, abi=get_erc20_token_abi())
        tx = contract.functions.mint(contract_address, 1262 * 10**18).build_transaction({'from': self.deployer_address, 'gasPrice': self.w3.to_wei('2', 'gwei'), 'nonce': self.w3.eth.get_transaction_count(self.deployer_address)})

        signed_txn = self.w3.eth.account.sign_transaction(tx, private_key=self.deployer_key)

        tx_hash = self.w3.eth.send_raw_transaction(signed_txn.raw_transaction)

        tx_receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300, poll_latency=1)

        if tx_receipt['status'] == 1:
            logger.success(f"Prefunded {contract_address} with 1262 ZEN")
            send_status('success', f"Prefunded {contract_address} with 1262 ZEN")
            return tx_receipt
        else:
            logger.error(f"Failed to prefund {contract_address} with 1262 ZEN")
            send_status('error', f"Failed to prefund {contract_address} with 1262 ZEN")
            return False
        