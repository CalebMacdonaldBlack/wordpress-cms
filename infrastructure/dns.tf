data "aws_route53_zone" "zone" {
  name = "${var.domain_name}"
}

locals {
  full_domain_name = "${var.name}.${var.domain_name}"
}

resource "aws_route53_record" "alias" {
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${local.full_domain_name}"
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = "${aws_alb.alb.dns_name}"
    zone_id                = "${aws_alb.alb.zone_id}"
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "${local.full_domain_name}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  zone_id = "${data.aws_route53_zone.zone.id}"
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]

  timeouts {
    create = "60m"
  }
}
