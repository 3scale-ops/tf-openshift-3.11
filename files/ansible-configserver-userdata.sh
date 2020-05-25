#!/usr/bin/env bash

# Log everything we do.
set -x
exec > /var/log/user-data.log 2>&1

# OpenShift setup
# See: https://docs.openshift.org/latest/install_config/install/host_preparation.html

# Install packages required to setup OpenShift.
yum install -y wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools
yum update -y

sudo yum install -y "@Development Tools" python2-pip openssl-devel python-devel gcc libffi-devel
pip install -I ansible==2.6.5

