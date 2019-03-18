resource "aws_default_subnet" "subnet-a" {
  availability_zone = "${var.region}a"
}

resource "aws_default_subnet" "subnet-b" {
  availability_zone = "${var.region}b"
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_security_group" "db" {
  vpc_id = "${aws_default_subnet.subnet-a.vpc_id}"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.service.id}"]
  }
}

resource "aws_security_group" "service" {
  vpc_id = "${aws_default_subnet.subnet-a.vpc_id}"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  //
  //  ingress {
  //    from_port   = "${var.port}"
  //    to_port     = "${var.port}"
  //    protocol    = "TCP"
  //    cidr_blocks = ["${aws_default_vpc.default_vpc.cidr_block}"]
  //  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_string" "alb_name" {
  length  = 6
  special = false
}

resource "aws_alb_target_group" "alb_target_group" {
  name_prefix = "${random_string.alb_name.result}"
  port        = "${var.port}"
  protocol    = "HTTP"
  vpc_id      = "${aws_default_subnet.subnet-b.vpc_id}"
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "302,200"
    port     = "${var.port}"
  }
}

resource "aws_security_group" "inbound_sg" {
  vpc_id      = "${aws_default_subnet.subnet-a.vpc_id}"
  name        = "${var.name}-inbound-sg"
  description = "Allow HTTP from Anywhere into ALB"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "alb" {
  name            = "${var.name}-alb"
  subnets         = ["${aws_default_subnet.subnet-a.id}", "${aws_default_subnet.subnet-b.id}"]
  security_groups = ["${aws_security_group.inbound_sg.id}", "${aws_security_group.service.id}"]
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  depends_on        = ["aws_alb_target_group.alb_target_group"]

  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    type             = "forward"
  }

  ssl_policy      = ""
  certificate_arn = "${aws_acm_certificate_validation.cert_validation.certificate_arn}"
}
