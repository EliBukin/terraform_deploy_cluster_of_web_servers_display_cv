# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE ALL THE RESOURCES TO DEPLOY AN APP IN AN AUTO SCALING GROUP WITH AN ELB
# This template runs a web server displayes my CV in Auto Scaling Group (ASG) with an Elastic Load Balancer
# (ELB) in front of it to distribute traffic across the EC2 Instances in the ASG.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.12"
}

# ------------------------------------------------------------------------------
# CONFIGURE AWS CONNECTION
# ------------------------------------------------------------------------------

provider "aws" {
  version    = "~> 2.0"
  region     = "${var.aws_region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

# ---------------------------------------------------------------------------------------------------------------------
# GET THE LIST OF AVAILABILITY ZONES IN THE CURRENT REGION
# Every AWS accout has slightly different availability zones in each region. For example, one account might have
# us-east-1a, us-east-1b, and us-east-1c, while another will have us-east-1a, us-east-1b, and us-east-1d. This resource
# queries AWS to fetch the list for the current account and region.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_availability_zones" "all" {}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "sini_asg" {
  launch_configuration = aws_launch_configuration.sini_launch_configuration.id
  availability_zones   = data.aws_availability_zones.all.names

  min_size = 2
  max_size = 10

  load_balancers    = [aws_elb.sini_elb.name]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "terraform-asg-sini_asg"
    propagate_at_launch = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "sini_launch_configuration" {
  # Ubuntu Server 
  image_id        = "ami-03ef731cc103c9f09"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sini_security_group.id]
  user_data       = "${file("echo_apache.sh")}"

  # Whenever using a launch configuration with an auto scaling group, you must set create_before_destroy = true.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "sini_security_group" {
  name = "terraform-sini-instance"

  # Inbound HTTP from anywhere
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ELB TO ROUTE TRAFFIC ACROSS THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elb" "sini_elb" {
  name               = "terraform-sini-asg"
  security_groups    = [aws_security_group.elb.id]
  availability_zones = data.aws_availability_zones.all.names

  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # This adds a listener for incoming HTTP requests.
  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP THAT CONTROLS WHAT TRAFFIC AN GO IN AND OUT OF THE ELB
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "elb" {
  name = "terraform-sini-elb"

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port   = var.elb_port
    to_port     = var.elb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
