import os
import requests
from loguru import logger
from dotenv import load_dotenv

from src.discord_status import send_status

class VercelAPI:
    def __init__(self):
        load_dotenv(".env")
        self.vercel_uri = os.getenv('VERCEL_URI')
        self.vercel_jwt = os.getenv('VERCEL_JWT')
        self.vercel_project_name = os.getenv('VERCEL_PROJECT_NAME')
        self.vercel_env_name = os.getenv('VERCEL_ENV_NAME')
        self.vercel_deployment_url = os.getenv('VERCEL_DEPLOYMENT_URL')

        self.headers = {
            'Authorization': f'Bearer {self.vercel_jwt}',
            'Content-Type': 'application/json'
            }
        
        self.vercel_env_id = self._retrieve_env_id()
        
        self.url = f'https://api.vercel.com/v9/projects/{self.vercel_project_name}/env/{self.vercel_env_id}'

    def _retrieve_env_id(self):
        response = requests.get(
            f'https://api.vercel.com/v9/projects/{self.vercel_project_name}/env?decrypt=true',
            headers=self.headers
        )

        for env in response.json()['envs']:
            if env['key'] == self.vercel_env_name and 'production' in env['target']:
                return env['id']
            
    def _retrieve_deployment_id(self):
        response = requests.get(
            f'https://api.vercel.com/v13/deployments/{self.vercel_deployment_url}',
            headers=self.headers
        )

        return response.json()['id']

    def update_battleships_env(self, address):
        json_data = {
            'comment': 'current battleships deployed contract',
            'key': self.vercel_env_name,
            'target': ['production'],
            'type': 'encrypted',
            'value': address,
        }
        response = requests.patch(
            self.url,
            headers=self.headers,
            json=json_data,
        )

        if response.status_code == 200:
            logger.success(f'Updated {self.vercel_env_name} with {address}')
            send_status('success', f'Updated {self.vercel_env_name} with {address}')
            return True
        
        else: 
            logger.error(f'Error updating {self.vercel_env_name}: {response.json()}')
            send_status('error', f'Error updating {self.vercel_env_name}: {response.json()}')
            return False

        return False
    
    def redeploy(self):
        
        redeploy_url = "https://api.vercel.com/v13/deployments?forceNew=0&skipAutoDetectionConfirmation=0"
        
        json_data = {
            "name": self.vercel_project_name,
            "deploymentId": self._retrieve_deployment_id(),
            'target': 'production',
            "withLatestCommit": True
        }

        response = requests.post(
            redeploy_url,
            headers=self.headers,
            json=json_data,
        )

        if response.status_code == 200:
            logger.success(f'Redeployed {self.vercel_project_name}.')
            send_status('success', f'Redeployed {self.vercel_project_name}.')
            return response.json()  # return the response for further inspection if needed
        else:
            logger.error(f'Error redeploying {self.vercel_project_name}')
            send_status('error', f'Error redeploying {self.vercel_project_name}: {response.json()}')
            return False
