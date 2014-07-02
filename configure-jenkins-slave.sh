#!/bin/bash

modules_dir="/etc/puppet/modules"
manifest="jenkins-manifest.pp"

## These are used to setup cnaf maven repo credentials. These variables should be set
## before running this script.
MVN_REPO_CNAF_USER=${MVN_REPO_CNAF_USER:-''}
MVN_REPO_CNAF_PASSWORD=${MVN_REPO_CNAF_PASSWORD:-''}

echo "Creating manifest file for jenkins-slave setup"

if [ -z "${MVN_REPO_CNAF_USER}" ]; then
  echo "Error: MVN_REPO_CNAF_USER is not set"
  exit 1
fi

if [ -z "${MVN_REPO_CNAF_PASSWORD}" ]; then
  echo "Error: MVN_REPO_CNAF_PASSWORD is not set"
  exit 1
fi

cat << EOF > $manifest
class { 'puppet-jenkins-slave':
        maven_servers_data => [
          { id = 'cnaf-releases', login => '${MVN_REPO_CNAF_USER}', pwd => '${MVN_REPO_CNAF_PASSWORD}'},
          { id = 'cnaf-snapshots', login => '${MVN_REPO_CNAF_USER}', pwd => '${MVN_REPO_CNAF_PASSWORD}'}
      ]
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
