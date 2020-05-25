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

