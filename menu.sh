#!/bin/bash

#get path of menu correct
pushd ~/IOTstack

CURRENT_BRANCH=${1:-$(git name-rev --name-only HEAD)}

# Consts/vars
TMP_DOCKER_COMPOSE_YML=./.tmp/docker-compose.tmp.yml
DOCKER_COMPOSE_YML=./docker-compose.yml
DOCKER_COMPOSE_OVERRIDE_YML=./compose-override.yml
BASE_DIR=./
HASSIO_DIR=./hassio

# Load params from file
[ -f ./.params_menu ] && . ./.params_menu

PORTS_FILE=$BASE_DIR/ports_parts.phtml
GLOBAL_PORTS=""

# Minimum Software Versions
COMPOSE_VERSION="3.6"
REQ_DOCKER_VERSION=18.2.0
REQ_PYTHON_VERSION=3.6.9
REQ_PYYAML_VERSION=5.3.1

declare -A cont_array=(
	[portainer]="Portainer"
	[portainer_agent]="Portainer agent"
	[nodered]="Node-RED"
	[influxdb]="InfluxDB"
	[telegraf]="Telegraf (Requires InfluxDB and Mosquitto)"
	[transmission]="transmission"
	[grafana]="Grafana"
	[mosquitto]="Eclipse-Mosquitto"
	[prometheus]="Prometheus"
	[postgres]="Postgres"
	[timescaledb]="Timescaledb"
	[mariadb]="MariaDB (MySQL fork)"
	[adminer]="Adminer"
	[openhab]="openHAB"
	[zigbee2mqtt]="zigbee2mqtt"
	[deconz]="deCONZ ConBee/RaspBee Zigbee gateways "
	[pihole]="Pi-Hole DNS Manager"
	[plex]="Plex media server"
	[tasmoadmin]="TasmoAdmin"
	[rtl_433]="RTL_433 to mqtt"
	[espruinohub]="EspruinoHub"
	[motioneye]="motionEye"
	[webthings_gateway]="Mozilla webthings-gateway"
	[blynk_server]="blynk-server"
	[nextcloud]="Next-Cloud"
	[nginx]="NGINX by linuxserver"
        [nginx-manager]="NGINX Manager Proxy"
	[diyhue]="diyHue"
	[homebridge]="Homebridge"
	[python]="Python 3"
	[gitea]="Gitea"
	[qbittorrent]="qbittorrent"
	[domoticz]="Domoticz"
	[dozzle]="Dozzle"
	[wireguard]="Wireguard"
	[zabbix]="Zabbix Monitor Server"
	[meshcentral]="Mesh Central mini server"
	# add yours here
)

declare -a armhf_keys=(
	"portainer"
	"portainer_agent"
	"nodered"
	"influxdb"
	"grafana"
	"mosquitto"
	"telegraf"
	"prometheus"
	"mariadb"
	"postgres"
	"timescaledb"
	"transmission"
	"adminer"
	"openhab"
	"zigbee2mqtt"
  	"deconz"
	"pihole"
	"plex"
	"tasmoadmin"
	"rtl_433"
	"espruinohub"
	"motioneye"
	"webthings_gateway"
	"blynk_server"
	"nextcloud"
	"diyhue"
	"homebridge"
	"python"
	"gitea"
	"qbittorrent"
	"domoticz"
	"dozzle"
	"wireguard"
	"nginx-manager"
	"zabbix"
	"meshcentral"
	# add yours here
)
sys_arch=$(uname -m)

#timezones
timezones() {

	env_file=$1
	TZ=$(cat /etc/timezone)

	#test for TZ=
	[ $(grep -c "TZ=" $env_file) -ne 0 ] && sed -i "/TZ=/c\TZ=$TZ" $env_file

}

# this function creates the volumes, services and backup directories. It then assisgns the current user to the ACL to give full read write access
docker_setfacl() {
	[ -d $BASE_DIR/services ] || mkdir -p $BASE_DIR/services
	[ -d $BASE_DIR/volumes ] || mkdir  -p $BASE_DIR/volumes
	[ -d $BASE_DIR/backups ] || mkdir  -p $BASE_DIR/backups
	[ -d $BASE_DIR/tmp ] || mkdir  -p $BASE_DIR/tmp

	#give current user rwx on the volumes and backups
	[ $(getfacl  $BASE_DIR/volumes | grep -c "default:user:$USER") -eq 0 ] && sudo setfacl -Rdm u:$USER:rwx  $BASE_DIR/volumes
	[ $(getfacl  $BASE_DIR/backups | grep -c "default:user:$USER") -eq 0 ] && sudo setfacl -Rdm u:$USER:rwx  $BASE_DIR/backups
}

#future function add password in build phase
password_dialog() {
	while [[ "$passphrase" != "$passphrase_repeat" || ${#passphrase} -lt 8 ]]; do

		passphrase=$(whiptail --passwordbox "${passphrase_invalid_message}Please enter the passphrase (8 chars min.):" 20 78 3>&1 1>&2 2>&3)
		passphrase_repeat=$(whiptail --passwordbox "Please repeat the passphrase:" 20 78 3>&1 1>&2 2>&3)
		passphrase_invalid_message="Passphrase too short, or not matching! "
	done
	echo $passphrase
}
#test=$( password_dialog )

function command_exists() {
	command -v "$@" > /dev/null 2>&1
}

function minimum_version_check() {
	# minimum_version_check required_version current_major current_minor current_build
	# minimum_version_check "1.2.3" 1 2 3
	REQ_MIN_VERSION_MAJOR=$(echo "$1"| cut -d' ' -f 2 | cut -d'.' -f 1)
	REQ_MIN_VERSION_MINOR=$(echo "$1"| cut -d' ' -f 2 | cut -d'.' -f 2)
	REQ_MIN_VERSION_BUILD=$(echo "$1"| cut -d' ' -f 2 | cut -d'.' -f 3)

	CURR_VERSION_MAJOR=$2
	CURR_VERSION_MINOR=$3
	CURR_VERSION_BUILD=$4
	
	VERSION_GOOD="Unknown"

	if [ -z "$CURR_VERSION_MAJOR" ]; then
		echo "$VERSION_GOOD"
		return 1
	fi

	if [ -z "$CURR_VERSION_MINOR" ]; then
		echo "$VERSION_GOOD"
		return 1
	fi

	if [ -z "$CURR_VERSION_BUILD" ]; then
		echo "$VERSION_GOOD"
		return 1
	fi

	if [ "${CURR_VERSION_MAJOR}" -ge $REQ_MIN_VERSION_MAJOR ]; then
		VERSION_GOOD="true"
		echo "$VERSION_GOOD"
		return 0
	else
		VERSION_GOOD="false"
	fi

	if [ "${CURR_VERSION_MAJOR}" -ge $REQ_MIN_VERSION_MAJOR ] && \
		[ "${CURR_VERSION_MINOR}" -ge $REQ_MIN_VERSION_MINOR ]; then
		VERSION_GOOD="true"
		echo "$VERSION_GOOD"
		return 0
	else
		VERSION_GOOD="false"
	fi

	if [ "${CURR_VERSION_MAJOR}" -ge $REQ_MIN_VERSION_MAJOR ] && \
		[ "${CURR_VERSION_MINOR}" -ge $REQ_MIN_VERSION_MINOR ] && \
		[ "${CURR_VERSION_BUILD}" -ge $REQ_MIN_VERSION_BUILD ]; then
		VERSION_GOOD="true"
		echo "$VERSION_GOOD"
		return 0
	else
		VERSION_GOOD="false"
	fi

	echo "$VERSION_GOOD"
}

function install_python3_and_deps() {
	CURR_PYTHON_VER="${1:-Unknown}"
	CURR_PYYAML_VER="${2:-Unknown}"
	if (whiptail --title "Python 3 and Dependencies" --yesno "Python 3.6.9 or later (Current = $CURR_PYTHON_VER), PyYaml 5.3.1 or later (Current = $CURR_PYYAML_VER) and pip3 is required for compose-overrides.yml file to merge into the docker-compose.yml file. Install these now?" 20 78); then
		sudo apt install -y python3-pip python3-dev
		if [ $? -eq 0 ]; then
			PYTHON_VERSION_GOOD="true"
		else
			echo "Failed to install Python"
			exit 1
		fi
		pip3 install -U pyyaml==5.3.1
				if [ $? -eq 0 ]; then
			PYYAML_VERSION_GOOD="true"
		else
			echo "Failed to install Python"
			exit 1
		fi
	fi
}

function do_python3_pip() {
	PYTHON_VERSION_GOOD="false"
	PYYAML_VERSION_GOOD="false"

	if command_exists python3 && command_exists pip3; then
		PYTHON_VERSION=$(python3 --version)
		echo "Python Version: ${PYTHON_VERSION:-Unknown}"
		PYTHON_VERSION_MAJOR=$(echo "$PYTHON_VERSION"| cut -d' ' -f 2 | cut -d'.' -f 1)
		PYTHON_VERSION_MINOR=$(echo "$PYTHON_VERSION"| cut -d'.' -f 2)
		PYTHON_VERSION_BUILD=$(echo "$PYTHON_VERSION"| cut -d'.' -f 3)

		PYYAML_VERSION=$(python3 ./scripts/yaml_merge.py --pyyaml-version)
		PYYAML_VERSION="${PYYAML_VERSION:-Unknown}"
		PYYAML_VERSION_MAJOR=$(echo "$PYYAML_VERSION"| cut -d' ' -f 2 | cut -d'.' -f 1)
		PYYAML_VERSION_MINOR=$(echo "$PYYAML_VERSION"| cut -d'.' -f 2)
		PYYAML_VERSION_BUILD=$(echo "$PYYAML_VERSION"| cut -d'.' -f 3)

		if [ "$(minimum_version_check $REQ_PYTHON_VERSION $PYTHON_VERSION_MAJOR $PYTHON_VERSION_MINOR $PYTHON_VERSION_BUILD)" == "true" ]; then
			PYTHON_VERSION_GOOD="true"
		else
			echo "Python is outdated."
			install_python3_and_deps "$PYTHON_VERSION_MAJOR.$PYTHON_VERSION_MINOR.$PYTHON_VERSION_BUILD" "$PYYAML_VERSION_MAJOR.$PYYAML_VERSION_MINOR.$PYYAML_VERSION_BUILD"
			return 1
		fi
		echo "PyYaml Version: $PYYAML_VERSION"
		if [ "$(minimum_version_check $REQ_PYYAML_VERSION $PYYAML_VERSION_MAJOR $PYYAML_VERSION_MINOR $PYYAML_VERSION_BUILD)" == "true" ]; then
			PYYAML_VERSION_GOOD="true"
		else
			echo "PyYaml is outdated."
			if [ "$PYYAML_VERSION" != "Unknown" ]; then
				install_python3_and_deps "$PYTHON_VERSION_MAJOR.$PYTHON_VERSION_MINOR.$PYTHON_VERSION_BUILD" "$PYYAML_VERSION_MAJOR.$PYYAML_VERSION_MINOR.$PYYAML_VERSION_BUILD"
			else
				install_python3_and_deps "$PYTHON_VERSION_MAJOR.$PYTHON_VERSION_MINOR.$PYTHON_VERSION_BUILD"
			fi
			return 1
		fi
	else
		install_python3_and_deps
		return 1
	fi
}

#function copies the template yml file to the local service folder and appends to the docker-compose.yml file
function yml_builder() {

	service="$BASE_DIR/services/$1/service.yml"
	local_msg=""

	[ -d $BASE_DIR/services/ ] || mkdir -p $BASE_DIR/services/

	if [ -d $BASE_DIR/services/$1 ]; then
		#directory already exists prompt user to overwrite
		sevice_overwrite=$(whiptail --radiolist --title "Overwrite Option" --notags \
			"$1 service directory has been detected, use [SPACEBAR] to select you overwrite option" 20 78 12 \
			"none" "Do not overwrite" "ON" \
			"env" "Preserve Environment and Config files" "OFF" \
			"full" "Pull full service from template" "OFF" \
			3>&1 1>&2 2>&3)

		case $sevice_overwrite in

		"full")
			echo "...pulled full $1 from template"
			rsync -a -q .templates/$1/ $BASE_DIR/services/$1/ --exclude 'build.sh'
			get_details $1
            ;;
		"env")
			echo "...pulled $1 excluding env file"
			rsync -a -q .templates/$1/ $BASE_DIR/services/$1/ --exclude 'build.sh' --exclude '$1.env' --exclude '*.conf'
			;;
		"none")
			echo "...$1 service not overwritten"
			;;

		esac

	else
		mkdir -p  $BASE_DIR/services/$1
		echo "...pulled full $1 from template"
		rsync -a -q .templates/$1/  $BASE_DIR/services/$1/ # --exclude 'build.sh'
		get_details $1
	fi

	#if an env file exists check for timezone
	[ -f "$BASE_DIR/services/$1/$1.env" ] && timezones  $BASE_DIR/services/$1/$1.env

	# if a volumes.yml exists, append to overall volumes.yml file
	[ -f "$BASE_DIR/services/$1/volumes.yml" ] && cat " $BASE_DIR/services/$1/volumes.yml" >> docker-volumes.yml

	#add new line then append service
	echo "" >> $TMP_DOCKER_COMPOSE_YML
	#fixing volumes
	sed -i "s|\.\/volumes|$BASE_DIR\/volumes|g" $service
	sed -i "s|\.\/services|$BASE_DIR\/services|g" $service
	cat $service >> $TMP_DOCKER_COMPOSE_YML

	#test for post build
	if [ -f ./.templates/$1/build.sh ]; then
		chmod +x ./.templates/$1/build.sh
		bash ./.templates/$1/build.sh  $BASE_DIR
	fi

	#test for directoryfix.sh
	if [ -f ./.templates/$1/directoryfix.sh ]; then
		chmod +x ./.templates/$1/directoryfix.sh
		echo "...Running directoryfix.sh on $1"
		bash ./.templates/$1/directoryfix.sh  $BASE_DIR
	fi

	#make sure terminal.sh is executable
	[ -f  $BASE_DIR/services/$1/terminal.sh ] && chmod +x  $BASE_DIR/services/$1/terminal.sh

}


# Get Ports an pass 
# parameter : name of service
function get_details(){
	service_process=$1
	servicefile="$BASE_DIR/services/$service_process/service.yml"
	messagefile=".templates/$1/message.txt"
	sed_string=()
	local_status=0

	[ -f $messagefile ] && whiptail --title "Mesagge from $service_process" --msgbox --scrolltext "$(cat $messagefile)" 20 60 3>&1 1>&2 2>&3
	while IFS= read -r line
	do
		if [ $local_status = 1 ]; then
			if [[ $line == *"- "* ]] && [[ $line == *"\""* ]]; then
				outport=$( echo $line |cut -d'"' -f2 |cut -d":" -f1 )
				inport=$( echo $line |cut -d':' -f2 |cut -d'"' -f1 )
				is_ok=0
				while [ $is_ok -eq 0 ]; do
					is_ok=1
				    replaceport=$(whiptail --inputbox "Map port $inport to external port" 8 39 $outport --title "Ports of service $service_process" 3>&1 1>&2 2>&3)
					exitstatus=$?
					if [ $exitstatus = 0 ]; then
						localports=$(netstat -putona |grep ":$replaceport ")
						echo -- $localports -- $is_ok
						[ -z $localports ] || is_ok=0
						[[ $GLOBAL_PORTS == *":$replaceport" ]] && is_ok=0
						if [ $is_ok = 1 ]; then
							sed_string+=("s|$outport:$inport|$replaceport:$inport|g")
						else
							whiptail --title "Port $replaceport is in use" --msgbox "Port $replaceport is used by system or by oter deploy." 8 78
						fi
					fi        

				done
			else
				local_status=0
			fi
		fi
		if [ $local_status = 2 ]; then
			if [[ $line == *"- "* ]]; then
				nameofvalue=$( echo $line |cut -d'-' -f2 |cut -d"=" -f1|tr -d [:blank:] )
				value=$( echo $line |cut -d'=' -f2 |cut -d'"' -f1 )
				replacevalue=$(whiptail --inputbox "Set value for $nameofvalue" 8 39 $value --title "Value for service $service_process" 3>&1 1>&2 2>&3)
				exitstatus=$?
				if [ $exitstatus = 0 ]; then
					sed_string+=("s|$nameofvalue=$value|$nameofvalue=$replacevalue|g")
				fi        
			else
				local_status=0
			fi
		fi

		if [ $local_status = 0 ]; then
			if [[ $line == *"ports:"* ]]; then
				local_status=1
			fi
			if [[ $line == *"environment:"* ]]; then
				local_status=2
			fi
		fi
	done < "$servicefile"

	for rep in ${sed_string[@]} ; do
		sed -i "$rep" $servicefile 
		done
}


# Get all Ports  
# parameter : docker-compose file
function get_all_ports(){
	
    rm $PORTS_FILE
	touch $PORTS_FILE
	# read local ip
	localip=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
	if [ -z $localip ]; then
	  localip=$(ifconfig wlan0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
	fi 
	#docker-compose ps |while IFS= read -r line
	#do
	#	echo $line
	#	if [[ $line == *"->"* ]]; then
	#		#has port
    #         is_service=$( echo $line |cut -d" " -f1 )
	#		 is_port=$(echo $line|cut -d":" -f2|cut -d"-" -f1)
	#		echo "<tr>  <td class='th'>Service : $is_service </td> <td><a href=http://$localip:$is_port>$is_port</a></td> </tr>" >> $PORTS_FILE
    #   fi

	#done 
	for d in $BASE_DIR/services/*/ ; do
		if [ -f $d/ports.out ]; then
			is_service=$(echo $d |rev|cut -d"/" -f 2|rev)
			or_port=$(cat $d/ports.out|tr -d [:blank:] )
			is_port=$(cat $d/service.yml| grep ":$or_port"|cut -d'"' -f 2|cut -d":" -f1)
			echo $is_service $or_port $is_port
			echo "<tr>  <td class='th'>Service : $is_service </td> <td><a href=http://$localip:$is_port>$is_port</a></td> </tr>" >> $PORTS_FILE
		fi
		
	done
}

# AUX funcion - press enter to continue
# optional param : text
# returm key
function press_enter () {
  [ -z $1 ] && localmsg="Press ENTER to continue..."
  read -n 1 -s -r -p "$localmsg"
}

#----------
# only as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
   else
   echo "Run as root: OK"
fi


#---------------------------------------------------------------------------------------------------
# Project updates
echo "checking for project update"
git fetch origin master

if [ $(git status | grep -c "Your branch is up to date") -eq 1 ]; then
	#delete .outofdate if it exisist
	[ -f .outofdate ] && rm .outofdate
	echo "Project is up to date"

else
	echo "An update is available for the project"
	if [ ! -f .outofdate ]; then
		whiptail --title "Project update" --msgbox "An update is available for the project\nYou will not be reminded again until you next update" 8 78
		touch .outofdate
	fi
fi

#---------------------------------------------------------------------------------------------------
# Docker updates
if command_exists docker; then
	echo "checking docker version"
	DOCKER_VERSION=$(docker version -f "{{.Server.Version}}")
	DOCKER_VERSION_MAJOR=$(echo "$DOCKER_VERSION"| cut -d'.' -f 1)
	DOCKER_VERSION_MINOR=$(echo "$DOCKER_VERSION"| cut -d'.' -f 2)
	DOCKER_VERSION_BUILD=$(echo "$DOCKER_VERSION"| cut -d'.' -f 3)

	if [ "$(minimum_version_check $REQ_DOCKER_VERSION $DOCKER_VERSION_MAJOR $DOCKER_VERSION_MINOR $DOCKER_VERSION_BUILD )" == "true" ]; then
		echo "Docker version >= $REQ_DOCKER_VERSION. You are good to go."
	else
		if (whiptail --title "Docker and Docker-Compose Version Issue" --yesno "Docker version is currently $DOCKER_VERSION which is less than $REQ_DOCKER_VERSION consider upgrading or you may experience issues. You can manually upgrade by typing 'sudo apt upgrade docker docker-compose'. Attempt to upgrade now?" 20 78); then
			sudo apt upgrade docker docker-compose
		fi
	fi
else
	echo "docker not installed"
fi



#---------------------------------------------------------------------------------------------------
# Menu system starts here
# Display main menu
do_loop=1
while [ $do_loop = 1 ] ; do
	mainmenu_selection=$(whiptail --title "Main Menu" --menu --notags \
		"" 20 78 12 -- \
		"install" "Install Docker" \
		"build" "Build Stack" \
		"hassio" "Install Home Assistant (Requires Docker)" \
		"native" "Native Installs" \
		"commands" "Docker commands" \
		"backup" "Backup options" \
		"misc" "Miscellaneous commands" \
		"web" "Start a 'miniweb' server" \
		"configure" "Base directory configuration" \
		"version" "Version Info" \
		"update" "Update IOTstack" \
		"exit" "Exit" \
		3>&1 1>&2 2>&3)

	exitstatus=$?
	if [ $exitstatus = 0 ]; then
	case $mainmenu_selection in
	#MAINMENU Install docker  ------------------------------------------------------------
	"version")
	     [ -f "IOTStack.version" ] && whiptail --title "Version Info" --msgbox --scrolltext "$(cat IOTStack.version)" 20 60 3>&1 1>&2 2>&3
		;;
	"install")
		#sudo apt update && sudo apt upgrade -y ;;

		if command_exists docker; then
			echo "docker already installed"
		else
			echo "Install Docker"
			curl -fsSL https://get.docker.com | sh
			sudo usermod -aG docker $USER
		fi

		if command_exists docker-compose; then
			echo "docker-compose already installed"
		else
			echo "Install docker-compose"
			sudo apt install -y docker-compose
		fi

		if (whiptail --title "Restart Required" --yesno "It is recommended that you restart your device now. Select yes to do so now" 20 78); then
			sudo reboot
		fi
		;;
		#MAINMENU Build stack ------------------------------------------------------------
	"build")

		title=$'Container Selection'
		message=$'Use the [SPACEBAR] to select which containers you would like to install'
		entry_options=()

		#check architecture and display appropriate menu
		if [ $(echo "$sys_arch" | grep -c "arm") ]; then
			keylist=("${armhf_keys[@]}")
		else
			echo "your architecture is not supported yet"
			exit
		fi

		#loop through the array of descriptions
		for index in "${keylist[@]}"; do
			entry_options+=("$index")
			entry_options+=("${cont_array[$index]}")

			#check selection
			if [ -f ./services/selection.txt ]; then
				[ $(grep "$index" ./services/selection.txt) ] && entry_options+=("ON") || entry_options+=("OFF")
			else
				entry_options+=("OFF")
			fi
		done

		container_selection=$(whiptail --title "$title" --notags --separate-output --checklist \
			"$message" 20 78 12 -- "${entry_options[@]}" 3>&1 1>&2 2>&3)

		mapfile -t containers <<<"$container_selection"

		#if no container is selected then dont overwrite the docker-compose.yml file
		if [ -n "$container_selection" ]; then
			touch $TMP_DOCKER_COMPOSE_YML
			GLOBAL_PORTS=""
			echo "version: '$COMPOSE_VERSION'" > $TMP_DOCKER_COMPOSE_YML
			echo "services:" >> $TMP_DOCKER_COMPOSE_YML

			#set the ACL for the stack
			docker_setfacl

			# store last sellection
			[ -f ./services/selection.txt ] && rm ./services/selection.txt
			#first run service directory wont exist
			[ -d ./services ] || mkdir services
			touch ./services/selection.txt
			#Run yml_builder of all selected containers
			for container in "${containers[@]}"; do
				echo "Adding $container container"
				yml_builder "$container"
				echo "$container" >>./services/selection.txt
			done

			if [ -f "$DOCKER_COMPOSE_OVERRIDE_YML" ]; then
				do_python3_pip
				
				if [ "$PYTHON_VERSION_GOOD" == "true" ] && [ "$PYYAML_VERSION_GOOD" == "true" ]; then
					echo "merging docker overrides with docker-compose.yml"
					python3 ./scripts/yaml_merge.py $TMP_DOCKER_COMPOSE_YML  $DOCKER_COMPOSE_OVERRIDE_YML $DOCKER_COMPOSE_YML
				else
					echo "incorrect python or dependency versions, aborting override and using docker-compose.yml"
					cp $TMP_DOCKER_COMPOSE_YML $DOCKER_COMPOSE_YML
				fi
			else
				echo "no override found, using docker-compose.yml"
				cp $TMP_DOCKER_COMPOSE_YML $DOCKER_COMPOSE_YML
			fi
			if (whiptail --title "Docker-compose generated" --yesno "Launch now ?" 8 40); then
    					docker-compose up -d 
					press_enter
					get_all_ports
				else
         			whiptail --title "Launch Instruction" --msgbox "run 'docker-compose up -d' to start the stack" 8 78
			fi
		else

			echo "Build cancelled"

		fi
		;;
		#MAINMENU Docker commands -----------------------------------------------------------
	"commands")

		docker_selection=$(
			whiptail --title "Docker commands" --menu --notags \
				"Shortcut to common docker commands" 20 78 12 -- \
				"aliases" "Add iotstack_up and iotstack_down aliases" \
				"status" "Status of stack in Docker" \
				"start" "Start stack" \
				"restart" "Restart stack" \
				"stop" "Stop stack" \
				"stop_all" "Stop any running container regardless of stack" \
				"pull" "Update all containers" \
				"prune_volumes" "Delete all stopped containers and docker volumes" \
				"prune_images" "Delete all images not associated with container" \
				"purge" "Purge all data from $BASE_DIR" \
				3>&1 1>&2 2>&3
		)

		case $docker_selection in
		"start") ./scripts/start.sh ;;
		"stop") ./scripts/stop.sh ;;
		"stop_all") ./scripts/stop-all.sh ;;
		"restart") ./scripts/restart.sh ;;
		"pull") ./scripts/update.sh ;;
		"prune_volumes") ./scripts/prune-volumes.sh ;;
		"prune_images") ./scripts/prune-images.sh ;;
		"clean") ./scripts/clean-containers ;;
		"purge") ./scripts/clean-data.sh $BASE_DIR ;;
		"status")
			clear
			docker-compose ps
			press_enter
			;;
		"aliases")
			touch ~/.bash_aliases
			if [ $(grep -c 'IOTstack' ~/.bash_aliases) -eq 0 ]; then
				echo ". ~/IOTstack/.bash_aliases" >>~/.bash_aliases
				echo "added aliases"
			else
				echo "aliases already added"
			fi
			source ~/.bashrc
			echo "aliases will be available after a reboot"
			;;
		esac
		;;
		#Backup menu ---------------------------------------------------------------------
	"backup")
		backup_sellection=$(whiptail --title "Backup Options" --menu --notags \
			"Select backup option" 20 78 12 -- \
			"dropbox-uploader" "Dropbox-Uploader" \
			"rclone" "google drive via rclone" \
			3>&1 1>&2 2>&3)

		case $backup_sellection in

		"dropbox-uploader")
			if [ ! -d ~/Dropbox-Uploader ]; then
				git clone https://github.com/andreafabrizi/Dropbox-Uploader.git ~/Dropbox-Uploader
				chmod +x ~/Dropbox-Uploader/dropbox_uploader.sh
				pushd ~/Dropbox-Uploader && ./dropbox_uploader.sh
				popd
			else
				echo "Dropbox uploader already installed"
			fi

			#add enable file for Dropbox-Uploader
			[ -d ~/IOTstack/backups ] || sudo mkdir -p ~/IOTstack/backups/
			sudo touch ~/IOTstack/backups/dropbox
			;;
		"rclone")
			sudo apt install -y rclone
			echo "Please run 'rclone config' to configure the rclone google drive backup"

			#add enable file for rclone
			[ -d ~/IOTstack/backups ] || sudo mkdir -p ~/IOTstack/backups/
			sudo touch ~/IOTstack/backups/rclone
			;;
		esac
		;;
		#MAINMENU Misc commands------------------------------------------------------------
	"misc")
		misc_sellection=$(
			whiptail --title "Miscellaneous Commands" --menu --notags \
				"Some helpful commands" 20 78 12 -- \
				"swap" "Disable swap by uninstalling swapfile" \
				"swappiness" "Disable swap by setting swappiness to 0" \
				"log2ram" "install log2ram to decrease load on sd card, moves /var/log into ram" \
                                "wirewardqr" "Show QR codes for Wiregrad VPN" \
				"wirewardfl" "Show config file for WireWard VPN" \
				3>&1 1>&2 2>&3
		)

		case $misc_sellection in
		"swap")
			sudo dphys-swapfile swapoff
			sudo dphys-swapfile uninstall
			sudo update-rc.d dphys-swapfile remove
			sudo systemctl disable dphys-swapfile
			#sudo apt-get remove dphys-swapfile
			echo "Swap file has been removed"
			;;
		"swappiness")
			if [ $(grep -c swappiness /etc/sysctl.conf) -eq 0 ]; then
				echo "vm.swappiness=0" | sudo tee -a /etc/sysctl.conf
				echo "updated /etc/sysctl.conf with vm.swappiness=0"
			else
				sudo sed -i "/vm.swappiness/c\vm.swappiness=0" /etc/sysctl.conf
				echo "vm.swappiness found in /etc/sysctl.conf update to 0"
			fi

			sudo sysctl vm.swappiness=0
			echo "set swappiness to 0 for immediate effect"
			;;
		"log2ram")
			if [ ! -d ~/log2ram ]; then
				git clone https://github.com/azlux/log2ram.git ~/log2ram
				chmod +x ~/log2ram/install.sh
				pushd ~/log2ram && sudo ./install.sh
				popd
			else
				echo "log2ram already installed"
			fi
			;;
                "wirewardqr")
                        if command_exists qrencode; then
                               peer=$(whiptail --inputbox "Numerical Peer" 8 39 1 --title "Enter peer numerical order" 3>&1 1>&2 2>&3)
				if [ $exitstatus = 0 ]; then
    					if [ -f $BASE_DIR/services/wireguard/config/peer$peer/peer$peer.conf ]; then
						qrencode -t ansiutf8 < $BASE_DIR/services/wireguard/config/peer$peer/peer$peer.conf
						press_enter
					fi
				fi
                        else
                          whiptail --title "Error" --msgbox "Is Wireward Installed ??" 8 78
                        fi
                        ;;
                "wirewardfl")
                        if command_exists qrencode; then
                               peer=$(whiptail --inputbox "Numerical Peer" 8 39 1 --title "Enter peer numerical order" 3>&1 1>&2 2>&3)
                                if [ $exitstatus = 0 ]; then
                                        if [ -f $BASE_DIR/services/wireguard/config/peer$peer/peer$peer.conf ]; then
						clear
						echo #---------- file wireward peer$peer
                                                cat $BASE_DIR/services/wireguard/config/peer$peer/peer$peer.conf
						echo #----------
						echo
                                                press_enter
                                        fi
                                fi
                        else
                          whiptail --title "Error" --msgbox "Is Wireward Installed ??" 8 78
                        fi
                        ;;
		esac
		;;

	"hassio")
		echo "Installing Home Asssistant
		HASSIO_DIR=./hassio
                docker run -d \
                     --name homeassistant \
                     --privileged \
                     --restart=unless-stopped \
                     -v $HASSIO_DIR:/config \
                     --network=host \
                     ghcr.io/home-assistant/home-assistant:stable
			mkdir -p $HASSIO_DIR
			press_enter
		else
			echo "no selection"
			exit
		fi
		;;
	"update")
		clear
		echo "Pulling latest project file from Github.com ---------------------------------------------"
		git pull origin $CURRENT_BRANCH
		echo "git status ------------------------------------------------------------------------------"
		git status
		echo "-----------------------------------------------------------------------------------------"
		echo "Reload menu.sh"
		exit
		;;
	"native")

		native_selections=$(whiptail --title "Native installs" --menu --notags \
			"Install local applications" 20 78 12 -- \
			"rtl_433" "RTL_433" \
			"rpieasy" "RPIEasy" \
			"netdata" "NetData monitor" \
			"cockpit" "CockPit Remote manager and terminal" \
			"zabbix" "Local zabbix agent" \
			"duckdns" "Enable and Configure DuckDNS" \
			"zerotier" "Enable and Configure Zero Tier" \
			3>&1 1>&2 2>&3)

		case $native_selections in
		"rtl_433")
			bash ./.native/rtl_433.sh
			;;
		"rpieasy")
			bash ./.native/rpieasy.sh
			;;
		"netdata")
			bash <(curl -Ss https://my-netdata.io/kickstart.sh)
			service netdata start
			whiptail --title "NetData is working" --msgbox "Netdata is working on port 19999" 10 78
			;;
		"cockpit")
			echo 'deb http://deb.debian.org/debian stretch-backports main' > /etc/apt/sources.list.d/backports.list
			apt-key adv --keyserver keyserver.ubuntu.com --recv 7638D0442B90D010
			apt update
			apt -y install cockpit cockpit-docker
			service cockpit start
			whiptail --title "CockPit is working" --msgbox "Cockpit is working on port 9090" 10 78
			;;
		"zabbix")
			wget https://repo.zabbix.com/zabbix/5.2/raspbian/pool/main/z/zabbix-release/zabbix-release_5.2-1%2Bdebian10_all.deb
			dpkg -i zabbix*.deb 
			apt update
			apt install -y zabbix-agent
			rm -f zabbix*.deb
			;;
		"duckdns")
			duck_selection=$(whiptail --title "DuckDNS" --menu --notags \
			"DuckDNS configure and install" 20 78 12 -- \
			"configure" "Configure DuckDNS" \
			"install" "Install DuckDNS autoupdate Script" \
			3>&1 1>&2 2>&3)
			case $duck_selection in
				"configure")
					$duck_dns_key=''
					$duck_dns_domain=''
					[ -f ./.duckdns.param ] && . ./.duckdns.param
					duck_dns_key=$(whiptail --inputbox "DuckDNS Tocken" 8 39 $duck_dns_key --title "DuckDNS" 3>&1 1>&2 2>&3)
					duck_dns_domain=$(whiptail --inputbox "DuckDNS Domain" 8 39 $duck_dns_domain --title "DuckDNS" 3>&1 1>&2 2>&3)
					echo "duck_dns_key=$duck_dns_key" > ./.duckdns.param
					echo "duck_dns_domain=$duck_dns_domain" >> ./.duckdns.param
					;;
				"install")
					if [ -f ".duckdns.param" ]; then
						. ./.duckdns.param
						mkdir -p /opt/duckdns
						echo "echo url=\"https://www.duckdns.org/update?domains=$duck_dns_domain&token=$duck_dns_key\" | curl -k -o /var/log/duck.log -K -" > /opt/duckdns/duckdns.sh
						chmod 700 /opt/duckdns/duckdns.sh
						sed -i '/duckdns/d' /etc/crontab
						echo "00 1    * * *   root   /opt/duckdns/duckdns.sh " >> /etc/crontab
						service cron restart
						/opt/duckdns/duckdns.sh
					else
						whiptail --title "DuckDNS ERROR" --msgbox "Please, configure DuckDNS first." 8 78
					fi
				esac
			;;
                "zerotier")
                        zero_tier=$(whiptail --title "Zero Tier" --menu --notags \
                        "Zero Tier configure and install" 20 78 12 -- \
			"install" "Install ZeroTier client" \
                        "configure" "Configure Zero Tier" \
                        "info" "Info about ZeroTier install" \
                        3>&1 1>&2 2>&3)
                        case $zero_tier in
                                "configure")
                                        zero_tier_id=''
                                        [ -f ./.zerotier.param ] && . ./.zerotier.param
                                        zero_tier_id=$(whiptail --inputbox "ZeroTier Network ID" 8 39 $zero_tier_id --title "DuckDNS" 3>&1 1>&2 2>&3 )
                                        echo "zero_tier_id=$zero_tier_id" > ./.zerotier.param
					clear
					zerotier-cli join $zero_tier_id
					press_enter
                                        ;;
                                "install")
					clear
					curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg' | gpg --import && \
					if z=$(curl -s 'https://install.zerotier.com/' | gpg); then echo "$z" | sudo bash; fi
					press_enter
				        ;;
				"info")
				zerotier_info=$(zerotier-cli info)
				press_intro
				whiptail --title "Zero Tier Info" --msgbox "$zerotier_info. You must hit OK to continue." 8 78
                        esac
			;;
		esac
		;;
	"configure")

		BASE_DIR=$(whiptail --inputbox "Fullpath to storage volumes and configuration" 8 39 $BASE_DIR --title "Configura dir" 3>&1 1>&2 2>&3)
		HASSIO_DIR=$(whiptail --inputbox "Fullpath to storage HASSIO files" 8 39 $HASSIO_DIR --title "Configura dir" 3>&1 1>&2 2>&3)
		echo "BASE_DIR=$BASE_DIR" > ./.params_menu
		echo "HASSIO_DIR=$HASSIO_DIR" >> ./.params_menu
		;; 
	"web")
	    if [ -f $BASE_DIR/ports_parts.phtml ]; then
		    localip=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
			if [ -z $localip ]; then
	  				localip=$(ifconfig wlan0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
			fi
			if (whiptail --title "Start mini web server" --yesno "Start mini web server at http://$localip:18008 press CTRL-C to exit" 16 40); then
						get_all_ports
						clear
    					bash scripts/tsws 0.0.0.0 18008 $BASE_DIR/ports_parts.phtml
			fi
		else
		    whiptail --title "No InfoFile" --msgbox "Run Build Stack first" 8 78
		fi
	    ;;
	"exit")
		exit
		do_loop=0
		;;
	*) ;;

	esac
	else
     do_loop=0
	fi
done
popd > /dev/null 2>&1
