resource "aws_route53_record" "this-cname" {
  zone_id = var.zone_id
  name    = var.cname_name
  type    = "CNAME"
  ttl     = "30"
  records = var.cname_targets
}
