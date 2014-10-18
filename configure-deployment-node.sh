#!/bin/bash
modules_dir="/etc/puppet/modules"
manifest="deploy-manifest.pp"

echo "Creating manifest file"

cat << EOF > deploy-manifest.pp
include puppet-cloud-vm
include puppet-egi-trust-anchors
include puppet-test-ca
include puppet-infn-ca
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
