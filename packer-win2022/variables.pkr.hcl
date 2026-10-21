variable "subscription_id" { type = string }
variable "image_version"   { type = string } # e.g. "1.0.0"
variable "location" {
  type    = string
  default = "eastus"
}
