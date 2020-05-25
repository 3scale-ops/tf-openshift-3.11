# OpenShift Inventory Template.

# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
etcd
nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
# SSH user, this user should allow ssh based auth without requiring a password
ansible_ssh_user=centos

# If ansible_ssh_user is not root, ansible_become must be set to true
ansible_become=true

# Deploy OpenShift 3.11 Enterprise
openshift_deployment_type=openshift-enterprise
openshift_release=v3.11

oreg_auth_user=${oreg_auth_user}
oreg_auth_password=${oreg_auth_password}

# DNS setup
openshift_master_default_subdomain=${default_subdomain}
openshift_master_cluster_hostname=${cluster_hostname}

# Use an htpasswd file as the indentity provider.
openshift_master_identity_providers=${identity_providers}
openshift_master_htpasswd_users={"admin":"${admin_password}"}

openshift_is_atomic=True
openshift_clock_enabled=True

#Storage
openshift_master_dynamic_provisioning_enabled=True

# SDN
os_sdn_network_plugin_name=redhat/openshift-ovs-multitenant

# Logging
openshift_logging_install_logging=false
#openshift_logging_storage_kind=dynamic
#openshift_logging_es_pvc_size=500Gi
#openshift_logging_es_cluster_size=3
#openshift_logging_es_pvc_storage_class_name="gp2"
#openshift_logging_es_memory_limit=16G
#openshift_logging_kibana_nodeselector={"node-role.kubernetes.io/infra": "true"}
#openshift_logging_curator_nodeselector={"node-role.kubernetes.io/infra": "true"}
#openshift_logging_es_nodeselector={"node-role.kubernetes.io/infra": "true"}
#openshift_logging_es_nodeselector={"type": "elasticsearch"}

# Metrics
openshift_metrics_install_metrics=false
# openshift_metrics_storage_kind=dynamic
# openshift_metrics_storage_volume_size=50Gi
# openshift_metrics_cassandra_storage_type=dynamic
# openshift_metrics_cassandra_pvc_storage_class_name="gp2"
# openshift_metrics_hawkular_nodeselector={"node-role.kubernetes.io/infra": "true"}
# openshift_metrics_cassandra_nodeselector={"node-role.kubernetes.io/infra": "true"}
# openshift_metrics_heapster_nodeselector={"node-role.kubernetes.io/infra": "true"}

# Use API keys rather than instance roles so that tenant containers don't get
# Openshift's EC2/EBS permissions
openshift_cloudprovider_kind=aws
openshift_cloudprovider_aws_access_key=${aws_access_key}
openshift_cloudprovider_aws_secret_key=${aws_secret_key}

# Set the cluster_id.
openshift_clusterid=${cluster_id}

# Define the standard set of node groups, as per:
#   https://github.com/openshift/openshift-ansible#node-group-definition-and-mapping
openshift_node_groups=[{'name': 'node-config-master', 'labels': ['node-role.kubernetes.io/master=true']}, {'name': 'node-config-infra', 'labels': ['node-role.kubernetes.io/infra=true']}, {'name': 'node-config-compute', 'labels': ['node-role.kubernetes.io/compute=true']}, {'name': 'node-config-master-infra', 'labels': ['node-role.kubernetes.io/infra=true,node-role.kubernetes.io/master=true']}, {'name': 'node-config-all-in-one', 'labels': ['node-role.kubernetes.io/infra=true,node-role.kubernetes.io/master=true,node-role.kubernetes.io/compute=true']}]

# Create the masters host group. Note that due do:
#   https://github.com/dwmkerr/terraform-aws-openshift/issues/40
# We cannot use the internal DNS names (such as master.openshift.local) as there
# is a bug with the installer when using the AWS cloud provider.
# Note that we use the master node as an infra node as well, which is not recommended for production use.
[masters]
${master_nodes_list}

# host group for etcd
[etcd]
${master_nodes_list}

# all nodes - along with their openshift_node_groups.
[nodes]
${master_nodes_list}
${worker_nodes_list}
