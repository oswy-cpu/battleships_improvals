import os
import json
import requests

class request_funds:
    def __init__(self):
        self.faucet_uri = os.getenv('FAUCET_URI')
        self.faucet_jwt = os.getenv('FAUCET_JWT')
    
    def request(self, wallet, retry = 0):
        if retry > 5:
            return False
        try:
            response = requests.post(url=self.faucet_uri, 
                                            data=json.dumps({'address': wallet}),
                                            headers = {'Content-Type': 'application/json',
                                                    'Authorization': f'Bearer {self.faucet_jwt}'})
            
            if response.json()['status'] == 'ok':
                return True

            return False
        except:
            self.request(wallet, retry + 1)
