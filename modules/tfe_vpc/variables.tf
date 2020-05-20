variable "vpc_name" {
  type        = string
  description = "Name tag added to the VPC"
}

variable "tags" {
  type        = map(string)
  description = "The value placed in the 'owner' tag on resources created by this module"
}

variable "cidr_block" {
  type        = string
  description = "Main CIDR block for the VPC"
}

variable "ipv6" {
  type        = bool
  description = "Booleans on whether to auto-generate an IPv6 CIDR for this VPC"
  default     = false
}

variable "additional_cidrs" {
  type        = list
  default     = []
  description = "A list of additional CIDR ranges assigned to this VPC"
}

variable "azs" {
  type        = list
  default     = ["a", "b"]
  description = "A list of suffix letters to specify which AZs that subnets should be created within."
}
