#!/bin/sh
set -e

# Make sure the server folder exists
mkdir -p ${MOONLIGHT_WEB_PATH}/server

CONFIG_PATH=${MOONLIGHT_WEB_PATH}/server/config.json
DEFAULT_CONFIG_PATH=${MOONLIGHT_WEB_PATH}/defaults/config.json

# Copy default config if none exists
if [ ! -f "${CONFIG_PATH}" ]; then
    cp "${DEFAULT_CONFIG_PATH}" "${CONFIG_PATH}"
fi

export CONFIG_PATH DEFAULT_CONFIG_PATH
python3 <<'PY'
import json
import os
import sys

config_path = os.environ['CONFIG_PATH']
defaults_path = os.environ['DEFAULT_CONFIG_PATH']

def load_json(path: str):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except (FileNotFoundError, json.JSONDecodeError):
        return None

config = load_json(config_path)
if not isinstance(config, dict):
    print('Config file invalid or missing required structure, resetting to defaults.', file=sys.stderr)
    config = load_json(defaults_path)

if not isinstance(config, dict):
    print('Failed to load default configuration.', file=sys.stderr)
    sys.exit(1)

def parse_list(env_name: str):
    raw = os.environ.get(env_name)
    if not raw:
        return None
    values = [item.strip() for item in raw.split(',') if item.strip()]
    return values

def parse_int(env_name: str):
    raw = os.environ.get(env_name)
    if not raw:
        return None
    try:
        return int(raw)
    except ValueError:
        print(f"Invalid {env_name}: {raw}", file=sys.stderr)
        return None

bind_address = os.environ.get('ML_WEB_BIND_ADDRESS')
if bind_address:
    config['bind_address'] = bind_address
else:
    bind_ip = os.environ.get('ML_WEB_BIND_IP')
    bind_port = os.environ.get('ML_WEB_PORT')
    if bind_ip or bind_port:
        current = config.get('bind_address', '0.0.0.0:8080')
        if ':' in current:
            current_ip, current_port = current.rsplit(':', 1)
        else:
            current_ip, current_port = '0.0.0.0', '8080'
        config['bind_address'] = f"{bind_ip or current_ip}:{bind_port or current_port}"

credentials = os.environ.get('ML_WEB_CREDENTIALS')
if credentials is not None:
    if credentials.lower() == 'null':
        config['credentials'] = None
    elif credentials:
        config['credentials'] = credentials

pair_name = os.environ.get('ML_WEB_PAIR_DEVICE_NAME')
if pair_name:
    config['pair_device_name'] = pair_name

ice_urls = parse_list('ML_WEB_ICE_SERVER_URLS')
if 'webrtc_ice_servers' not in config or not isinstance(config['webrtc_ice_servers'], list) or not config['webrtc_ice_servers']:
    config['webrtc_ice_servers'] = [{'urls': [], 'username': '', 'credential': ''}]

ice_server = config['webrtc_ice_servers'][0]
if not isinstance(ice_server, dict):
    ice_server = {'urls': [], 'username': '', 'credential': ''}
    config['webrtc_ice_servers'][0] = ice_server

if ice_urls is not None:
    ice_server['urls'] = ice_urls

ice_username = os.environ.get('ML_WEB_ICE_USERNAME')
if ice_username is not None:
    ice_server['username'] = ice_username

ice_credential = os.environ.get('ML_WEB_ICE_CREDENTIAL')
if ice_credential is not None:
    ice_server['credential'] = ice_credential

nat_ips = parse_list('ML_WEB_NAT_IPS')
if nat_ips is not None:
    nat = config.get('webrtc_nat_1to1')
    if not isinstance(nat, dict):
        nat = {'ice_candidate_type': 'host', 'ips': []}
    nat['ips'] = nat_ips
    config['webrtc_nat_1to1'] = nat

nat_candidate_type = os.environ.get('ML_WEB_NAT_CANDIDATE_TYPE')
if nat_candidate_type:
    nat = config.get('webrtc_nat_1to1')
    if not isinstance(nat, dict):
        nat = {'ice_candidate_type': nat_candidate_type, 'ips': []}
    else:
        nat['ice_candidate_type'] = nat_candidate_type
    config['webrtc_nat_1to1'] = nat

port_min = parse_int('ML_WEB_WEBRTC_PORT_MIN')
if port_min is not None:
    config.setdefault('webrtc_port_range', {})['min'] = port_min

port_max = parse_int('ML_WEB_WEBRTC_PORT_MAX')
if port_max is not None:
    config.setdefault('webrtc_port_range', {})['max'] = port_max

network_types = parse_list('ML_WEB_WEBRTC_NETWORK_TYPES')
if network_types is not None:
    config['webrtc_network_types'] = network_types

web_path_prefix = os.environ.get('ML_WEB_WEB_PATH_PREFIX')
if web_path_prefix is not None:
    config['web_path_prefix'] = web_path_prefix

moonlight_port = parse_int('ML_WEB_MOONLIGHT_HTTP_PORT')
if moonlight_port is not None:
    config['moonlight_default_http_port'] = moonlight_port

streamer_path = os.environ.get('ML_WEB_STREAMER_PATH')
if streamer_path:
    config['streamer_path'] = streamer_path

tmp_path = config_path + '.tmp'
with open(tmp_path, 'w', encoding='utf-8') as fh:
    json.dump(config, fh, indent=2, sort_keys=True)
    fh.write('\n')

os.replace(tmp_path, config_path)
PY
# Run main application
exec ${MOONLIGHT_WEB_PATH}/web-server