variable "region" {
  default = "ap-southeast-2"
}

variable "name" {
  default = "coderock-wp"
}

variable "port" {
  default = 80
}

variable "db-password" {
  default = "partybus123"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "domain_name" {
  default = "kaidenplayer.xyz"
}

output "public_key_pem" {
  value = "${tls_private_key.private_key.public_key_pem}"
}

output "private_key_pem" {
  value = "${tls_private_key.private_key.private_key_pem}"
}

provider "aws" {
  region = "${var.region}"
}
