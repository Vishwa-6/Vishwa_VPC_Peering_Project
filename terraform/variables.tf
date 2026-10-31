variable "region" {
  description = "AWS Region for every resource (workbook example: Mumbai)."
  type        = string
  default     = "ap-south-1"
}

variable "student_name" {
  description = "Goes into the Student tag on every resource."
  type        = string
}

variable "my_ip_cidr" {
  description = "Your current public IPv4 as a /32, e.g. 203.0.113.25/32. Only this address may SSH to the bastion."
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}(\\.\\d{1,3}){3}/32$", var.my_ip_cidr)) && var.my_ip_cidr != "0.0.0.0/32"
    error_message = "Use a single IPv4 address as /32, for example 203.0.113.25/32. Never open SSH to 0.0.0.0/0."
  }
}

variable "public_key_path" {
  description = "Public half of the lab key. The private half never leaves your laptop."
  type        = string
  default     = "~/.ssh/ewb-lab.pem.pub"
}

variable "private_key_path" {
  description = "Local path of the private key, used only in the generated SSH config."
  type        = string
  default     = "~/.ssh/ewb-lab.pem"
}

variable "instance_type" {
  description = "Small x86 type. Check price and credits before applying."
  type        = string
  default     = "t3.micro"
}

variable "enable_peering" {
  description = "false = baseline (no peering, no peer routes). true = peering + routes on both sides."
  type        = bool
  default     = false
}

variable "app_b_icmp_enabled" {
  description = "true = App-B allows ICMP echo from App-A. Set false for the controlled failure test."
  type        = bool
  default     = true
}
