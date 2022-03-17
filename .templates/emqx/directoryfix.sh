#!/bin/bash
base_dir=$1
[ -d $base_dir/volumes/emqx ] || sudo mkdir -p $base_dir/volumes/emqx
[ -d $base_dir/volumes/emqx/data ] || sudo mkdir -p $base_dir/volumes/emqx/data
[ -d $base_dir/volumes/emqx/logs ] || sudo mkdir -p $base_dir/volumes/emqx/logs

chown -R 1000 $base_dir/volumes/emqx

