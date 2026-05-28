
main.tf
```tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}



# ─────────────────────────────────────────
# SECURITY GROUP FOR EC2
#
# Allows:
#   - Port 80  from internet  → so users can open the PHP app in browser
#   - Port 22  from your IP   → so you can SSH in for debugging
# ─────────────────────────────────────────
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-web-sg"
  description = "Allow HTTP from internet and SSH from my IP"
  vpc_id      = aws_vpc.main.id

  # HTTP — anyone can reach the web app
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH — only your machine
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Allow all outbound (EC2 needs to reach RDS and internet for yum updates)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-web-sg" }
}

# ─────────────────────────────────────────
# SECURITY GROUP FOR RDS
#
# Allows:
#   - Port 3306 (MySQL) ONLY from EC2 security group
#   - Nothing else — RDS is completely hidden from the internet
# ─────────────────────────────────────────
resource "aws_security_group" "rds_sg" {
  name        = "rds-mysql-sg"
  description = "Allow MySQL only from EC2 security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2 only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    # This references the EC2 SG directly — not an IP range.
    # Only traffic coming FROM ec2_sg is allowed. Nothing else.
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-mysql-sg" }
}
```


