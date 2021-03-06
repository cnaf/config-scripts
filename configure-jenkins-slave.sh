#!/bin/bash
manifest="jenkins-manifest.pp"

## These are used to setup cnaf maven repo credentials. These variables should be set
## before running this script.
MVN_REPO_CNAF_USER=${MVN_REPO_CNAF_USER:-''}
MVN_REPO_CNAF_PASSWORD=${MVN_REPO_CNAF_PASSWORD:-''}
HOSTNAME=$(hostname)

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
class { 'mwdevel_java': java_version => 8}
class { 'mwdevel_jenkins_slave':
        maven_servers_data => [
          { id => 'cnaf-releases', login => '${MVN_REPO_CNAF_USER}', pwd => '${MVN_REPO_CNAF_PASSWORD}'},
          { id => 'cnaf-snapshots', login => '${MVN_REPO_CNAF_USER}', pwd => '${MVN_REPO_CNAF_PASSWORD}'}
      ]
}

host { '${HOSTNAME}':
  ip => '127.0.0.1',
}

include mwdevel_users
include mwdevel_storm_build_deps
include mwdevel_voms_build_deps
include mwdevel_robot_framework
EOF

yum clean all
yum -y update

rm -rf /var/cache/yum/*

echo "Installing base puppet modules"

puppet module install --force maestrodev-wget
puppet module install --force gini-archive
puppet module install --force puppetlabs-stdlib
puppet module install --force maestrodev-maven
puppet module install --force puppetlabs-java

echo "Fetching puppet modules from: https://github.com/cnaf/ci-puppet-modules"

if [ ! -e "ci-puppet-modules" ]; then
  git clone https://github.com/cnaf/ci-puppet-modules.git
else
  pushd ci-puppet-modules
  git pull
  popd
fi

echo "Applying the following puppet manifest: $manifest"
cat $manifest

puppet apply --debug -v \
  --modulepath "/etc/puppet/modules:$(pwd)/ci-puppet-modules/modules" \
  $manifest
