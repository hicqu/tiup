#!/bin/bash

set -eu

version=${version-v4.0.4}
old_version=${old_version-v3.0.16}
name=test_upgrade_tls
topo=./topo/upgrade_tls.yaml

mkdir -p ~/.tiup/bin && cp -f ./root.json ~/.tiup/bin/

yes | tiup-cluster deploy $name $old_version $topo -i ~/.ssh/id_rsa

yes | tiup-cluster start $name
tiup-cluster exec $name -N n1 --command "grep -q ${name} /home/tidb/deploy/prometheus-9090/conf/*.rules.yml"
! tiup-cluster exec $name -N n1 --command "grep -q ENV_LABELS_ENV /home/tidb/deploy/prometheus-9090/conf/*.rules.yml"

tiup-cluster _test $name writable

yes | tiup-cluster upgrade $name $version --transfer-timeout 60

tiup-cluster _test $name writable

# test edit-config & reload
# change the config of pump and check it after reload
# https://stackoverflow.com/questions/5978108/open-vim-from-within-bash-shell-script
EDITOR=ex tiup-cluster edit-config -y $name <<EOEX
:%s/1 mib/2 mib/g
:x
EOEX

yes | tiup-cluster reload $name --transfer-timeout 60

tiup-cluster exec $name -R pump --command "grep '2 mib' /home/tidb/deploy/pump-8250/conf/pump.toml"

tiup-cluster _test $name writable

yes | tiup-cluster destroy $name
