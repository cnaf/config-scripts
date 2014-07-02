#!/bin/bash

modules_dir="/etc/puppet/modules"
manifest="jenkins-manifest.pp"

## Path to a comma-separated-value file describing known maven repositories 
## and containing lines in the following format:
## server_id,login,password
maven_server_conf="maven_server_conf.csv"

echo "Creating manifest file for jenkins-slave setup"

servers_params=""

#Set the internal field separator to ","
OLDIFS=$IFS
IFS=,
if [ -f $maven_server_conf ] && [ ! -z $maven_server_conf ]; then

  while read id login pwd
  do
          line="{ id => '$id', login => '$login', pwd => '$pwd' },"
          servers_params+=$line
  done < $maven_file

fi

IFS=$OLDIFS

cat << EOF > $manifest
class { 'puppet-jenkins-slave':
        maven_servers_data => [ $servers_params ]
}

include puppet-users
include puppet-storm-build-deps
include puppet-voms-build-deps
include puppet-robot-framework
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

puppet apply --color false --debug -v $manifest
