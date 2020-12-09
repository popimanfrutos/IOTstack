#!/bin/bash
if (whiptail --title "delete all data from $1" --yesno "This acion is NO RECOVERAVLE" 8 78); then 
	if (whiptail --title "Are you sure?" --yesno "There is no possibility of recovery" 8 78); then
			rm -rf $1 
			rm services/selection.txt
        fi
fi
