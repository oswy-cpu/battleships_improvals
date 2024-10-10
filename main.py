from src.redeploy import redeployContracts
import time
from loguru import logger

def main():
    redeploy = redeployContracts()
    
    while True:
        game_over = redeploy.get_game_status()
        logger.info(f"Has game ended: {game_over}")
        
        if game_over:
            if not redeploy.zen_address:
                logger.info("ZEN address not found. Redeploying ZEN token.")
                zen_address = redeploy.deploy_zen()
                redeploy.update_env('ZEN_ADDRESS', zen_address)
                
            redeploy.deploy_battleships()
            logger.info("Redeploying battleships. Restarting game check...")
            time.sleep(60)
        else:
            # Sleep before re-checking game status
            time.sleep(60)

main()