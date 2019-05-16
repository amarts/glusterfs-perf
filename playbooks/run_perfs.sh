#!/usr/bin/env bash

# This script executes the playbook using the variable files present in the
# vars/ directory present in roles dir or current dir.

VARS_DIR="/etc/ansible/roles/glusterfs.perf/playbooks/vars"
if [ ! -d $VARS_DIR ]; then
    echo "$VARS_DIR not found, exiting..."
    exit 1
fi

cd $VARS_DIR
# Make sure we start with a clean slate
# This is a overkill but can't help
for var in *.yml; do
    ansible-playbook -i $var ../cleanup.yml
done

# Run the tests
for var in *.yml; do
    ansible-playbook -i $var ../cluster_setup.yml
    # cleanup after the tests are run
    ansible-playbook -i $var ../cleanup.yml
done

# Send email
cd ../

ansible-playbook -i ./email-vars.yml ./sendmail-playbook.yml
