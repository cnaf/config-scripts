#!/bin/bash


## This is used to setup url for puppet modules. This variable should be set
## before running this script.

MODULES_URL=${MODULES_URL:-''}

if [ -z "${MODULES_URL}" ]; then
  echo "Error: MODULES_URL is not set"
  exit 1
fi

modules_dir="/etc/puppet/modules"
manifest="deploy-manifest.pp"

dest_file="/root/cloud-vm.tar.gz"

echo "Fetching puppet modules from: ${MODULES_URL}"
wget -q --no-check-certificate ${MODULES_URL} -O ${dest_file}

tar -xvzf ${dest_file} -C ${modules_dir}

echo "Creating manifest file"


cat << EOF > deploy-manifest.pp
include cloud-vm
include puppet-egi-trust-anchors
include puppet-test-ca
EOF

echo "Installing base puppet modules"

puppet module install --force maestrodev-wget
puppet module install --force gini-archive
puppet module install --force puppetlabs-stdlib
puppet module install --force maestrodev-maven
puppet module install --force puppetlabs-java

# Fetch all puppet modules from CNAF organization
echo "Fetching puppet modules from: https://github.com/cnaf"

list=$(curl https://api.github.com/orgs/cnaf/repos|grep html_url|sed  's/[",]//g'|sed -rn  's/.+(https.+(puppet))/\1/p'|sed  's/https/git/g')

for url in $list; do 
  repo=$(echo $url|sed -rn  's/(^git.+(puppet))/\2/p' )
  git clone $url $modules_dir/$repo;
done

echo "Applying the following puppet manifest: $manifest"
cat $manifest

puppet apply --debug -v $manifest
