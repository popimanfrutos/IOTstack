#!/bin/bash
base_dir=$1
WG_CONF_TEMPLATE_PATH=$base_dir/templates/wireguard/wg0.conf
WG_CONF_DEST_PATH=$base_dir/services/wireguard/config

if [[ ! -f $WG_CONF_TEMPLATE_PATH ]]; then
    echo "[Wireguard] Warning: $WG_CONF_TEMPLATE_PATH does not exist."
	# read -p "Press any key to resume ..."
  else
    [ -d $WG_CONF_DEST_PATH ] || mkdir -p $WG_CONF_DEST_PATH
    cp -r $WG_CONF_TEMPLATE_PATH $WG_CONF_DEST_PATH
fi
apt install -y qrencode
