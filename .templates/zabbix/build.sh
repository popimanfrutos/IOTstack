#!/bin/bash

local_status=0
#read variables and set into all .env

	while IFS= read -r line
	do
		if [ $local_status = 1 ]; then
			if [[ $line == *"- "* ]]; then
				nameofvalue=$( echo $line |cut -d'-' -f2 |cut -d"=" -f1|tr -d [:blank:] )
				value=$( echo $line |cut -d'=' -f2 |cut -d'"' -f1 )
				echo "$nameofvalue=$value" >> $1/services/zabbix/zabbix_server.env
				echo "$nameofvalue=$value" >> $1/services/zabbix/zabbix_db.env
			else
				local_status=0
			fi
		fi

		if [ $local_status = 0 ]; then
			if [[ $line == *"environment:"* ]]; then
				local_status=1
			fi
		fi
	done < $1/services/zabbix/service.yml
