resource "aws_db_subnet_group" "db-subnet-group" {
  subnet_ids = ["${aws_default_subnet.subnet-a.id}", "${aws_default_subnet.subnet-b.id}"]
}

resource "aws_security_group" "db-public" {
  vpc_id = "${aws_default_vpc.default_vpc.id}"

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

resource "aws_db_instance" "db" {
  instance_class         = "db.t2.micro"
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  allocated_storage      = 10
  name                   = "${replace(var.name,"-","")}db"
  apply_immediately      = true
  publicly_accessible    = true
  username               = "root"
  password               = "${var.db-password}"
  vpc_security_group_ids = ["${aws_security_group.db.id}", "${aws_security_group.db-public.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.db-subnet-group.name}"
}
