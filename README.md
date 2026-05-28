
main.tf 
```tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Mumbai Region
}

# ==================== DATA SOURCES ====================
# This automatically fetches your Default VPC details from AWS
data "aws_vpc" "default" {
  default = true
}

# This automatically fetches your Default Subnet IDs
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ==================== SECURITY GROUPS ====================

# 1. EC2 Security Group (Allows HTTP & SSH)
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-standalone-sg"
  description = "Allow inbound traffic for EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. RDS Security Group (Restricted to allow traffic ONLY from the EC2 instance)
resource "aws_security_group" "rds_sg" {
  name        = "rds-standalone-sg"
  description = "Allow inbound MySQL traffic from EC2 only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id] # Cross-referencing EC2 SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==================== RDS SUBNET GROUP ====================

# RDS requires a Subnet Group mapping at least 2 subnets even in a default VPC

/*

# Purana code (Jo saare subnets pass kar raha tha)
resource "aws_db_subnet_group" "default_db_group" {
  name       = "default-vpc-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

*/



# Naya Code (Jo sirf pehle 2 subnets select karega)
resource "aws_db_subnet_group" "default_db_group" {
  name       = "default-vpc-db-subnet-group"
  
  # slice() function default list me se sirf 0 aur 1 index wale subnets nikalega
  subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)
}


# ==================== AWS RESOURCES ====================

# 1. EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = "ami-03f4878755434977f" # Amazon Linux 2023 AMI for ap-south-1
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = file("${path.module}/userdata.sh")
  tags = {
    Name = "Standalone-Web-Server"
  }
}

# 2. RDS MySQL Database Instance
resource "aws_db_instance" "mysql_db" {
  allocated_storage      = 20
  db_name                = "mydatabase"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "SuperSecurePass123!" # Replace with your password
  db_subnet_group_name   = aws_db_subnet_group.default_db_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az               = false   # Single-AZ for this simple lab (set to true for production)
  skip_final_snapshot    = true
  publicly_accessible    = false   # Do NOT give RDS a public IP — it must stay private

  tags = {
    Name = "Standalone-MySQL-RDS"
  }
}

# ==================== OUTPUTS ====================

output "ec2_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.mysql_db.endpoint
}

```


This code uses all the default subnets present in your AWS account's Default VPC.
When you sign up for AWS, your Default VPC automatically comes with 1 default public subnet in every single Availability Zone (AZ) for that region [1].
Here is exactly how the code counts and handles them:

   1. How the code collects them: The data "aws_subnets" "default" block queries your AWS account and gathers the unique IDs of all those default subnets [2, 3].
   2. For Mumbai (ap-south-1): Since Mumbai has 3 Availability Zones (ap-south-1a, ap-south-1b, and ap-south-1c), this code automatically picks up 3 subnets.
   3. Passing to RDS: The aws_db_subnet_group takes all 3 of those Subnet IDs and passes them to the RDS instance.

Since 3 subnets is greater than the minimum requirement of 2 subnets, AWS accepts the code perfectly and safely launches your database.
------------------------------
Would you like me to show you how to restrict the code to use exactly 2 specific subnets instead of passing all of them?


Default VPC ke subnets ko limit karne ke liye aap apne data block ko slice kar sakte hain. Terraform ka built-in variable selection functions is kaam ko behad aasan bana deta hai.
Aap apne standalone main.tf code ke RDS SUBNET GROUP wale hisse me ja kar thodi si taba deeli karein:
## Code Tabdeeli (Modification)
Aapka purana subnet group code ye tha:

# Purana code (Jo saare subnets pass kar raha tha)
resource "aws_db_subnet_group" "default_db_group" {
  name       = "default-vpc-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

Usko badal kar aap ye wala naya code likhein:

# Naya Code (Jo sirf pehle 2 subnets select karega)
resource "aws_db_subnet_group" "default_db_group" {
  name       = "default-vpc-db-subnet-group"
  
  # slice() function default list me se sirf 0 aur 1 index wale subnets nikalega
  subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)
}

------------------------------
## Ye Kaam Kaise Karta Hai?
Terraform ka slice(list, start_index, end_index) function ek lambi list ko chota karne ke liye use hota hai:

* data.aws_subnets.default.ids: Yeh AWS Mumbai ke saare default subnet IDs (Total 3) uthata hai.
* , 0, 2): Yeh block Terraform ko batata hai ke list ke pehle element (index 0) se shuru kare aur index 2 se pehle tak ruk jaye. Is se aapko exact 2 unique Subnet IDs milte hain.

Ab agar aap terraform apply chalayenge, to AWS aapke database ko sirf unhi do specific default subnets me launch karega.
Agar aap ko is configuration me EC2 instance ko kisi specific subnet ke andar lock karna ho, to kya hum uski setting ko bhi dekhhein?


