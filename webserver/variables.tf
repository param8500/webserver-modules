variable "port" {
  type    = number
  default = 8080
}
variable "environment" {
  type = string
}
variable "db_remote_state_bucket" {
  type = string
}
variable "db_remote_state_key" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "min_size" {
  type = number
}
variable "max_size" {
  type = number
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}