variable "AWS_DEFAULT_REGION" {
  type    = string
  default = ""
}

variable "AWS_AZ" {
  type    = string
  default = "a"
}

variable "RDP_IP_ADDRESS" {
  type = string
  default = ""
}

variable "AWS_KEYPAIR_NAME" {
  type = string
  default = ""
}

variable "SPOT_OR_ON_DEMAND" {
  type = string
  default = ""
}