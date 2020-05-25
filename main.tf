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
# Intra cluster security group
#

resource "aws_security_group" "sg_nodes" {
  name        = format("%s-nodes-sg", var.name)
  description = "OpenShift instance security groups"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    var.tags,
    map("Name", format("%s-nodes-sg", var.name))
  )
}

#
# Ansible Configserver instance
#

data "template_file" "ansible_configserver_userdata" {
  template = file("${path.module}/files/ansible-configserver-userdata.sh")
}

data "template_file" "ansible_configserver_run" {
  template = file("${path.module}/files/ansible-configserver-run.sh")
}

data "template_file" "inventory_master_nodes_list" {
  template = file("${path.module}/files/ansible-configserver-inventory-master-node-list.tpl")
  count    = length(aws_instance.master)
  vars = {
    node     = format("master-%s-int.%s", count.index, var.dns_name)
    hostname = format("master.%s", var.dns_name)
  }
}

data "template_file" "inventory_worker_nodes_list" {
  template = file("${path.module}/files/ansible-configserver-inventory-worker-node-list.tpl")
  count    = length(aws_instance.worker)
  vars = {
    node = format("worker-%s-int.%s", count.index, var.dns_name)
  }
}

data "template_file" "inventory" {
  template = file("${path.module}/files/ansible-configserver-inventory.tpl")
  vars = {
    cluster_id         = var.name
    aws_access_key     = aws_iam_access_key.ocp_iam_user.id
    aws_secret_key     = aws_iam_access_key.ocp_iam_user.secret
    oreg_auth_user     = var.oreg_auth_user
    oreg_auth_password = var.oreg_auth_password
    admin_password     = var.admin_password
    cluster_hostname   = format("master.%s", var.dns_name)
    default_subdomain  = format("apps.%s", var.dns_name)
    master_nodes_list  = join("\n", data.template_file.inventory_master_nodes_list.*.rendered)
    worker_nodes_list  = join("\n", data.template_file.inventory_worker_nodes_list.*.rendered)
    identity_providers = var.identity_providers
  }
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

  provisioner "file" {
    content     = data.template_file.inventory.rendered
    destination = "~/openshift-ansible-inventory.cfg"

    connection {
      type  = "ssh"
      user  = "ec2-user"
      agent = true
      host  = self.public_ip
    }
  }

  provisioner "file" {
    content     = data.template_file.ansible_configserver_run.rendered
    destination = "~/ansible-configserver-run.sh"

    connection {
      type  = "ssh"
      user  = "ec2-user"
      agent = true
      host  = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/ansible-configserver-run.sh",
      "~/ansible-configserver-run.sh"
    ]

    connection {
      type  = "ssh"
      user  = "ec2-user"
      agent = true
      host  = self.public_ip
    }
  }
  timeouts {
    create = "3h"
    delete = "3h"
  }

  instance_initiated_shutdown_behavior = var.terminate_ansible_configserver ? "terminate" : "stop"

}

#
# Node intances
#

data "template_file" "node-cloudinit" {
  template = file("${path.module}/files/node-cloudinit.tpl")
  vars = {
    quay_registry_auth   = var.quay_registry_auth
    redhat_registry_auth = var.redhat_registry_auth
  }
}

#
# Node instances role
#

# Instance role
resource "aws_iam_role" "ocp_instance_role" {
  name               = format("%s-instance-role", var.name)
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

# Instance profile for the role
resource "aws_iam_instance_profile" "ocp_instance_profile" {
  name = format("%s-instance-profile", var.name)
  role = aws_iam_role.ocp_instance_role.name
}

# Policy for log forwarding
resource "aws_iam_policy" "ocp_forward_logs_iam_policy" {
  name        = format("%s-forward-logs-policy", var.name)
  path        = "/"
  description = "Allows an instance to forward logs to CloudWatch"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    }
  ]
}
EOF
}

# Log forwarding policy attachment
resource "aws_iam_policy_attachment" "ocp_forward_logs_iam_policy_attachment" {
  name       = "openshift-attachment-forward-logs"
  roles      = [aws_iam_role.ocp_instance_role.name]
  policy_arn = aws_iam_policy.ocp_forward_logs_iam_policy.arn
}

#
# OCP AWS IAM User
#

# User for openshift-only permissions
resource "aws_iam_user" "ocp_iam_user" {
  name = format("%s-user", var.name)
  path = "/"
}

# Access key for openshift-only permissions
resource "aws_iam_access_key" "ocp_iam_user" {
  user = aws_iam_user.ocp_iam_user.name
}

# OCP user policy for openshift-only permissions
resource "aws_iam_user_policy" "ocp_iam_user_policy" {
  name   = format("%s-user-policy", var.name)
  user   = aws_iam_user.ocp_iam_user.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolume*",
        "ec2:CreateVolume",
        "ec2:CreateTags",
        "ec2:DescribeInstance*",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:DeleteVolume",
        "ec2:DescribeSubnets",
        "ec2:CreateSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "ec2:DescribeRouteTables",
        "elasticloadbalancing:ConfigureHealthCheck",
        "ec2:AuthorizeSecurityGroupIngress",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:DescribeLoadBalancerAttributes"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

#
# Master node instance
#

resource "aws_instance" "master" {
  count         = var.masters_count
  ami           = data.aws_ami.atomic_linux.id
  instance_type = "t2.2xlarge"
  root_block_device {
    volume_size           = 48
    delete_on_termination = true
  }
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = 64
  }
  iam_instance_profile = aws_iam_instance_profile.ocp_instance_profile.id
  subnet_id            = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [
    aws_security_group.sg_nodes.id
  ]
  key_name  = var.openshift_key_pair
  user_data = data.template_file.node-cloudinit.rendered
  tags = merge(
    var.tags,
    map("Name", format("%s-master-%s", var.name, count.index)),
    map("DNS", format("master-%s.%s", count.index, var.dns_name)),
    map("KubernetesCluster", var.name),
    map(format("kubernetes.io/cluster/%s", var.name), "owned"),
    map("node-role.kubernetes.io/master", "true"),
    map("node-role.kubernetes.io/infra", "true")
  )
}

#
# Master nodes dns
#

resource "aws_route53_record" "master_node_dns" {
  count   = var.masters_count
  zone_id = var.dns_zone
  name    = format("master-%s.%s", count.index, var.dns_name)
  type    = "A"
  ttl     = 60
  records = aws_instance.master.*.public_ip
}

resource "aws_route53_record" "master_node_internal_dns" {
  count   = var.masters_count
  zone_id = var.dns_zone
  name    = format("master-%s-int.%s", count.index, var.dns_name)
  type    = "A"
  ttl     = 60
  records = aws_instance.master.*.private_ip
}

#
# Worker node instance
#

resource "aws_instance" "worker" {
  count         = var.workers_count
  ami           = data.aws_ami.atomic_linux.id
  instance_type = "t2.xlarge"
  root_block_device {
    volume_size           = 48
    delete_on_termination = true
  }
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = 64
  }
  iam_instance_profile = aws_iam_instance_profile.ocp_instance_profile.id
  subnet_id            = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [
    aws_security_group.sg_nodes.id
  ]
  key_name  = var.openshift_key_pair
  user_data = data.template_file.node-cloudinit.rendered
  tags = merge(
    var.tags,
    map("Name", format("%s-worker-%s", var.name, count.index)),
    map("DNS", format("worker-%s.%s", count.index, var.dns_name)),
    map("KubernetesCluster", var.name),
    map(format("kubernetes.io/cluster/%s", var.name), "owned"),
    map("node-role.kubernetes.io/compute", "true")
  )
}

#
# Worker nodes dns
#

resource "aws_route53_record" "worker_node_dns" {
  count   = var.workers_count
  zone_id = var.dns_zone
  name    = format("worker-%s.%s", count.index, var.dns_name)
  type    = "A"
  ttl     = 60
  records = aws_instance.worker[count.index].*.public_ip
}

resource "aws_route53_record" "worker_node_internal_dns" {
  count   = var.workers_count
  zone_id = var.dns_zone
  name    = format("worker-%s-int.%s", count.index, var.dns_name)
  type    = "A"
  ttl     = 60
  records = aws_instance.worker[count.index].*.private_ip
}

