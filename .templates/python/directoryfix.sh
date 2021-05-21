#!/bin/bash
base_dir=$1

# Directoryfix for python

#current user
u=$(whoami)

if [ ! -d $base_dir/volumes/python/app ]; then
	sudo mkdir -p $base_dir/volumes/python/app
	sudo chown -R $u:$u $base_dir/volumes/python
	echo 'print("hello world")' >$base_dir/volumes/python/app/app.py

fi
