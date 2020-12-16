#!/bin/bash
base_dir=$1
[ -d ./volumes/mosquitto ] || sudo mkdir -p ./volumes/mosquitto

#check user 1883
if [ $(grep -c 'user: \"1883\"' $base_dir/services/mosquitto/service.yml) -eq 1 ]; then
	echo "...found user 1883"
	sudo mkdir -p $base_dir/volumes/mosquitto/data/
	sudo mkdir -p $bae_dir/volumes/mosquitto/log/
	sudo mkdir -p $base_dir/volumes/mosquitto/pwfile/
	sudo chown -R 1883:1883 $base_dir/volumes/mosquitto/
fi

#check user 0 legacy test
if [ $(grep -c 'user: \"0\"' $base_dir/services/mosquitto/service.yml) -eq 1 ]; then
	echo "...found user 0 setting ownership for old template"
	sudo chown -R root:root $base_dir/volumes/mosquitto/
fi
