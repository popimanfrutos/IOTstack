#!/bin/bash
base_dir=$1
# create directories for named volumes
TRANSMISSION_BASEDIR=$base_dir/transmission
mkdir -p $TRANSMISSION_BASEDIR/downloads
mkdir -p $TRANSMISSION_BASEDIR/watch
mkdir -p $TRANSMISSION_BASEDIR/config
