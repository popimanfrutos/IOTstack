#!/bin/bash
basedir=$1
domain_1="your.domain.here"
domain=$(whiptail --inputbox "External domain fon MeshCentral" 8 39 $domain_1 --title "MeshCentral DOmain" 3>&1 1>&2 2>&3)
sed  "s/$domain_1/$domain/g" $basedir/services/meshcentral/config.json > $basedir/volumes/meshcentral/meshcentral-data/config.json
