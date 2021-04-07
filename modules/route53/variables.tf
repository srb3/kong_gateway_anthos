variable "zone_id" {
  description = "The name of the dns zone to use"
  type        = string
}

variable "cname_name" {
  description = "The name to give the cname record"
  type        = string
}

variable "cname_targets" {
  description = "A list of strings to act as the records referenced by the cname_name"
  type        = list(string)
}
