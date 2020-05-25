# Define the Amazon Linux AMI

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

# Define the AtomicOS Linux AMI

data "aws_ami" "atomic_linux" {
  most_recent = true
  owners      = ["410186602215"]
  filter {
    name   = "name"
    values = ["CentOS Atomic Host 7 x86_64 HVM EBS 18*"]
  }
}

#
# Ansible Configserver instance
#

data "template_file" "ansible_configserver_userdata" {
  template = file("${path.module}/files/ansible-configserver-userdata.sh")
}


resource "aws_instance" "ansible_configserver" {
  count         = 1
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "m5a.large"
  root_block_device {
    volume_size           = 48
    delete_on_termination = true
  }
  iam_instance_profile = aws_iam_instance_profile.ocp_instance_profile.id
  subnet_id            = var.public_subnet_ids[count.index]
  vpc_security_group_ids = [
    aws_security_group.sg_nodes.id
  ]
  key_name  = var.openshift_key_pair
  user_data = data.template_file.ansible_configserver_userdata.rendered
  tags = merge(
    var.tags,
    map("Name", format("%s-ansible-configserver", var.name)),
    map("DNS", format("ansible-configserver.%s", var.dns_name)),
    map("KubernetesCluster", var.name),
    map(format("kubernetes.io/cluster/%s", var.name), "owned"),
    map("node-role.kubernetes.io/configserver", "true")
  )

  timeouts {
    create = "3h"
    delete = "3h"
  }

  instance_initiated_shutdown_behavior = var.terminate_ansible_configserver ? "terminate" : "stop"

}

