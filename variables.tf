variable "name" {
  type        = string
  default     = ""
  description = "Cluster name"
}

variable "attributes" {
  type        = list(string)
  default     = []
  description = "Additional attributes (e.g. `1`)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. `map('BusinessUnit','XYZ')`"
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "VPC to launch the cluster instances into"
}

variable "private_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Private subnets to launch the cluster instances into"
}

variable "public_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Public subnets to launch cluster instances into"
}

variable "masters_count" {
  type        = number
  default     = 1
  description = "Number of master nodes"
}

variable "workers_count" {
  type        = number
  default     = 3
  description = "Number of worker nodes"
}

variable "openshift_key_pair" {
  type        = string
  default     = ""
  description = "AWS Key pair"
}

variable "dns_zone" {
  type        = string
  default     = ""
  description = "Cluster DNS Zone Id"
}

variable "dns_name" {
  type        = string
  default     = ""
  description = "Cluster DNS Zone Name"
}

variable "oreg_auth_user" {
  type        = string
  default     = ""
  description = "Red Hat registry user name"
}

variable "oreg_auth_password" {
  type        = string
  default     = ""
  description = "Red Hat registry user password"
}

variable "admin_password" {
  type        = string
  default     = ""
  description = "Admin password"
}

variable "quay_registry_auth" {
  type        = string
  default     = ""
  description = "Quay registry docker auth"
}

variable "redhat_registry_auth" {
  type        = string
  default     = ""
  description = "Red Hat registry docker auth"
}

variable "identity_providers" {
  type        = string
  default     = "[{'name':'htpasswd_auth','login':'true','challenge':'true','kind':'HTPasswdPasswordIdentityProvider'}]"
  description = "Openshift Identity Providers"
}

variable "terminate_ansible_configserver" {
  type        = bool
  default     = true
  description = "Terminates the ansible configserver after completing the deployment."
}
