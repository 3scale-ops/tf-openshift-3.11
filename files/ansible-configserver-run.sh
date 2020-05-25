#!/usr/bin/env bash

# Log everything we do.
set -x

# Retry function
function retry_command() {
    local -r __tries="$1"; shift
    local -r __run="$@"
    local -i __backoff_delay=2

    until $__run
        do
                if (( __current_try == __tries ))
                then
                        echo "Tried $__current_try times and failed!"
                        return 1
                else
                        echo "Retrying ...."
                        sleep $((((__backoff_delay++)) + ((__current_try++))))
                fi
        done
}

timeout 300 sed '/finish:\smodules-final:\sSUCCESS/q' <(tail -f /var/log/cloud-init.log)

retry_command 20 git clone -q -b release-3.11 https://github.com/openshift/openshift-ansible openshift-ansible

# Ansible
export ANSIBLE_HOST_KEY_CHECKING=False
retry_command 20 ansible-playbook -i ./openshift-ansible-inventory.cfg ./openshift-ansible/playbooks/prerequisites.yml
retry_command 20 ansible-playbook -i ./openshift-ansible-inventory.cfg ./openshift-ansible/playbooks/deploy_cluster.yml

# Stop the server
echo "Cluster deployment completed, bye!"
sudo shutdown -h 2