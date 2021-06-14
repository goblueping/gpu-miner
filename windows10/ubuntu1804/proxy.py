#!/usr/bin/env python3

# A simple http proxy to get info about overline_gpu_miner.
# This is to work around the issue of when running `wsl -u root bash -c "<command"`,
# it sometimes returns empty response.

import os
import time
import json
import argparse
import urllib
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
import logging
import logging.handlers
import socket

# 20 MB
log_filepath = os.path.join(os.path.expanduser("~"), 'overline_one_click_miner_proxy.log')
fh = logging.handlers.RotatingFileHandler(log_filepath, mode='a', maxBytes=20971520, backupCount=10)
fh.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
fh.setFormatter(formatter)
root_logger = logging.getLogger()
root_logger.setLevel(logging.INFO)
root_logger.addHandler(fh)
logger = logging.getLogger(__name__)

OVERLINE_GPU_MINER_EXECUTABLE = '/usr/local/bin/overline_gpu_miner'
BCNODE_CONTAINER_NAME = 'bcnode'

def run_command(command):
    logger.info('Running command: %s', command)
    try:
        output = subprocess.check_output(command, shell=True, timeout=10, stderr=subprocess.STDOUT, encoding='utf8')
        output = output.strip()
        return {'status': 'success', 'output': output}
    except subprocess.CalledProcessError as e:
        logger.exception('Failed to run command with CalledProcessError %s', e)
        return {'status': 'error', 'output': e.output}
    except subprocess.TimeoutExpired as e:
        logger.exception('Run command timed out with %s', e)
        return {'status': 'error', 'output': e.output}
    except Exception as e:
        logger.exception('Failed to run command with %s', e)
        return {'status': 'error', 'output': e.message}

# https://docs.microsoft.com/en-us/windows/wsl/compare-versions#accessing-network-applications
def get_ip_address():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.connect(('8.8.8.8', 80))
        return s.getsockname()[0]

class S(BaseHTTPRequestHandler):
    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header("Content-type", "application/json")
        self.end_headers()

    def to_json_binary(self, data):
        return json.dumps(data).encode('utf8')

    def do_HEAD(self):
        self._set_headers()

    def do_GET(self):
        parsed_path = urllib.parse.urlsplit(self.path)
        query = urllib.parse.parse_qs(parsed_path.query)

        command_type = query.get('command', [None])[0]

        if command_type is None:
            self._set_headers(400)
            self.wfile.write(self.to_json_binary({'error': 'command is required in the body'}))
            return
        if command_type == 'my_ip':
            ip = get_ip_address()
            result = {'status': 'success', 'output': ip}
            self._set_headers()
            self.wfile.write(self.to_json_binary(result))
            return

        if command_type == 'miner_key':
            command = f"{OVERLINE_GPU_MINER_EXECUTABLE} miner_key"
        elif command_type == 'status':
            command = f'{OVERLINE_GPU_MINER_EXECUTABLE} status'
        elif command_type == 'action_log':
            command = f'tail -n 20 {ACTION_LOG}'
        elif command_type == 'miner_log':
            epoch_time = int(time.time())
            command = f"docker logs --since {epoch_time-40} {BCNODE_CONTAINER_NAME}"
        elif command_type == 'check_executable':
            command = f"ls {OVERLINE_GPU_MINER_EXECUTABLE}"
        else:
            self._set_headers(400)
            self.wfile.write(self.to_json_binary({'error': 'invalid command'}))
            return

        result = run_command(command)
        logger.info('Ran command %s with result %s', command, result['status'])

        self._set_headers()
        self.wfile.write(self.to_json_binary(result))


def run(server_class=HTTPServer, handler_class=S, addr="0.0.0.0", port=8000):
    server_address = (addr, port)
    httpd = server_class(server_address, handler_class)

    logger.info(f"Starting httpd server on {addr}:{port}")
    httpd.serve_forever()


if __name__ == "__main__":
    run()
