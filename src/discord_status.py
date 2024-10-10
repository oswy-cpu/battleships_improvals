import os
import time
import requests
from dotenv import load_dotenv

load_dotenv(".env")

def send_status(level: str, status: str):
    webhook_url = os.getenv('DISCORD_WEBHOOK_URL')

    colors = {
        'success': 5620992, # Green
        'error': 16711680 # Red
    }

    embed = {
        'title': f'{level.capitalize()}',
        'description': status.capitalize(),
        'color': colors[level],
        "author": {"name": "Battleships Status"},
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    }

    data = {
        'embeds': [embed]
    }

    response = requests.post(webhook_url, json=data)