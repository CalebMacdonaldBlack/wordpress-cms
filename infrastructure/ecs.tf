resource "aws_ecs_cluster" "cluster" {
  name = "${var.name}"
}

resource "aws_cloudwatch_log_group" "joomla" {
  name = "${var.name}-logs"
}

resource "aws_cloudwatch_log_group" "db" {
  name = "${var.name}-db-logs"
}

data aws_iam_policy_document ec2_role {

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource aws_iam_role ec2_role {
  assume_role_policy = "${data.aws_iam_policy_document.ec2_role.json}"
}

data aws_iam_policy_document ec2_ecs_role_policy {

  statement {
    actions   = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "*"
    ]
  }
}

resource aws_iam_role_policy ec2_ecs_role_policy {
  name   = "${var.name}-ec2-ecs"
  role   = "${aws_iam_role.ec2_role.id}"
  policy = "${data.aws_iam_policy_document.ec2_ecs_role_policy.json}"
}

resource aws_iam_instance_profile ec2_instance_profile {
  name = "${var.name}-ec2-instance-profile"
  role = "${aws_iam_role.ec2_role.name}"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "${var.name}"
  public_key = "${tls_private_key.private_key.public_key_openssh}"
}

resource aws_instance ecs {
  ami                         = "ami-bc04d5de"
  instance_type               = "${var.instance_type}"
  subnet_id                   = "${aws_default_subnet.subnet-a.id}"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.ec2_instance_profile.id}"
  vpc_security_group_ids      = ["${aws_security_group.service.id}"]
  key_name                    = "${aws_key_pair.kp.key_name}"
  user_data                   = <<EOF
  #!/bin/bash
  echo ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config
  EOF
  tags {
    Name = "${var.name}"
  }

  provisioner file {
    source      = "./instance-provisioning-files/awslogs.conf"
    destination = "/tmp/awslogs.conf"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.private_key.private_key_pem}"
    }
  }

  provisioner remote-exec {
    inline = [
      "sudo yum install -y awslogs",
      "sudo mv /etc/awslogs/awslogs.conf /etc/awslogs/awslogs.conf.bak",
      "sudo mv /tmp/awslogs.conf /etc/awslogs/awslogs.conf",
      "sudo sed -i -e \"s/us-east-1/${var.region}/g\" /etc/awslogs/awscli.conf",
      "sudo sed -i -e \"s/{cluster}/${aws_ecs_cluster.cluster.name}/g\" /etc/awslogs/awslogs.conf",
      "sudo sed -i -e \"s/{container_instance_id}/${aws_instance.ecs.id}/g\" /etc/awslogs/awslogs.conf",
      "sudo service awslogs start",
      "sudo chkconfig awslogs on"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.private_key.private_key_pem}"
    }
  }
}

resource "aws_ecs_service" "service" {
  name            = "${var.name}"
  task_definition = "${aws_ecs_task_definition.service.arn}"
  launch_type     = "EC2"
  cluster         = "${aws_ecs_cluster.cluster.id}"
  desired_count   = 1

  network_configuration {
    subnets         = ["${aws_default_subnet.subnet-a.id}", "${aws_default_subnet.subnet-b.id}"]
    security_groups = ["${aws_security_group.service.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name   = "${var.name}"
    container_port   = "${var.port}"
  }
}

resource "aws_ecs_task_definition" "service" {
  family                   = "${var.name}"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn            = "${aws_iam_role.task.arn}"

  volume {
    name      = "${var.name}-storage"
    host_path = "/ecs/${var.name}-storage"
  }

  container_definitions = <<EOF
[
  {
    "name": "${var.name}",
    "mountPoints": [
      {
        "sourceVolume": "${var.name}-storage",
        "containerPath": "/var/www/html"
      }
    ],
    "image": "joomla",
    "portMappings": [
      {
        "containerPort": ${var.port},
        "hostPort": ${var.port}
      }
    ],
    "environment": [
       {
          "name": "JOOMLA_DB_HOST",
          "value": "${aws_db_instance.db.endpoint}"
        },
        {
          "name": "JOOMLA_DB_PASSWORD",
          "value": "${aws_db_instance.db.password}"
        },
        {
          "name": "JOOMLA_DB_NAME",
          "value": "${aws_db_instance.db.name}"
        }
    ],
    "cpu": 256,
    "memory": 512,
    "networkMode": "awsvpc",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.joomla.name}",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "${aws_cloudwatch_log_group.joomla.name}"
      }
    }
  }
]
EOF

  depends_on = ["aws_db_instance.db"]
}
