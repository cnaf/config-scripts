#!/bin/bash
modules_dir="/etc/puppet/modules"
manifest="deploy-manifest.pp"

echo "Installing base packages ... "
yum install -y puppet git

echo "Creating manifest file"

cat << EOF > deploy-manifest.pp
include mwdevel_cloud_vm
include mwdevel_egi_trust_anchors
include mwdevel_test_ca
include mwdevel_infn_ca
EOF

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
