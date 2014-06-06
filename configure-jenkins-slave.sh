#!/bin/bash

modules_dir="/etc/puppet/modules"
manifest="jenkins-manifest.pp"
maven_file="maven_settings.cvs"

echo "Creating manifest file for jenkins-slave setup"

servers_params=""

#Set the internal field separator to ","
OLDIFS=$IFS
IFS=,
if [ -f $maven_file ] && [ ! -z $maven_file ]; then

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

include puppet-storm-build-deps
include puppet-voms-build-deps
include puppet-robot-framework
EOF

echo "Installing custom puppet modules"

# install custom puppet modules
puppet module install --force maestrodev-wget
puppet module install --force gini-archive
puppet module install --force puppetlabs-stdlib
puppet module install --force maestrodev-maven
puppet module install --force puppetlabs-java

# Download all puppet modules from CNAF organization

echo "Fetching puppet modules from: https://github.com/cnaf"

list=$(curl https://api.github.com/orgs/cnaf/repos|grep html_url|sed  's/[",]//g'|sed -rn  's/.+(https.+(puppet))/\1/p'|sed  's/https/git/g')
for url in $list;do repo=$(echo $url|sed -rn  's/(^git.+(puppet))/\2/p' );git clone $url $modules_dir/$repo;done

echo "Applying puppet manifest: $manifest"
cat $manifest

puppet apply --color false --debug -v $manifest


