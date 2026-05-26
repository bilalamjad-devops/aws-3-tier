provider "aws" {
  region = "ap-south-1"
}

# ==========================================
# 1. NETWORKING LAYER (VPC, SUBNETS, ROUTING)
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "bilal-3tier-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "bilal-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "bilal-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "bilal-public-2"
  }
}

resource "aws_subnet" "private_app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "bilal-app-private-1"
  }
}

resource "aws_subnet" "private_app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "bilal-app-private-2"
  }
}

resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "bilal-db-private-1"
  }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "bilal-db-private-2"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "bilal-nat-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "bilal-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "bilal-private-rt"
  }
}

resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app_1" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_2" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_1" {
  subnet_id      = aws_subnet.private_db_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db_2" {
  subnet_id      = aws_subnet.private_db_2.id
  route_table_id = aws_route_table.private.id
}

# ==========================================
# 2. SECURITY GROUPS LAYER (FIREWALLS)
# ==========================================

resource "aws_security_group" "alb_sg" {
  name   = "bilal-alb-security-group"
  vpc_id = aws_vpc.main.id

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

resource "aws_security_group" "ec2_sg" {
  name   = "bilal-ec2-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "bilal-db-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 3. DATABASE TIER (RDS MY-SQL)
# ==========================================

resource "aws_db_subnet_group" "main" {
  name       = "bilal-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]
}

resource "aws_db_instance" "rds" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "bilal_db"
  username               = "admin"
  password               = "BilalSecurePass123!"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
}

# ==========================================
# 4. COMPUTE & LOAD BALANCER LAYER
# ==========================================

resource "aws_lb" "alb" {
  name               = "bilal-main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "bilal-ec2-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/index.php"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "bilal-lt-"
  image_id      = "ami-0dee22c13ea7a9a67"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx php-fpm php-mysql

              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "aws-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s -H "aws-metadata-token: \$TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              AVAILABILITY_ZONE=$(curl -s -H "aws-metadata-token: \$TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

              DB_HOST="${split(":", aws_db_instance.rds.endpoint)[0]}"

              cat <<EOP > /var/www/html/db_setup.php
              <?php
              \$conn = new mysqli("\$DB_HOST", "admin", "BilalSecurePass123!");
              \$conn->query("CREATE DATABASE IF NOT EXISTS bilal_db");
              \$conn->select_db("bilal_db");
              \$conn->query("CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50), email VARCHAR(50))");
              \$conn->close();
              ?>
              EOP

              php /var/www/html/db_setup.php

              cat <<EOP > /var/www/html/index.php
              <?php
              \$msg = "";
              if (\$_SERVER["REQUEST_METHOD"] == "POST") {
                  \$name = \$_POST['name'];
                  \$email = \$_POST['email'];
                  \$conn = new mysqli("\$DB_HOST", "admin", "BilalSecurePass123!", "bilal_db");
                  \$stmt = \$conn->prepare("INSERT INTO users (name, email) VALUES (?, ?)");
                  \$stmt->bind_param("ss", \$name, \$email);
                  \$stmt->execute();
                  \$msg = "Data successfully stored in secure RDS!";
                  \$stmt->close();
                  \$conn->close();
              }
              ?>
              <!DOCTYPE html>
              <html>
              <head>
                  <title>AWS 3-Tier Demo</title>
                  <style>
                      body { font-family: Arial, sans-serif; background: #f4f6f9; padding: 30px; }
                      .box { max-width: 600px; margin: auto; background: white; padding: 25px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                      .highlight { color: #ff9900; font-weight: bold; }
                      input[type=text], input[type=email] { width: 100%; padding: 10px; margin: 10px 0; box-sizing: border-box; }
                      input[type=submit] { background: #ff9900; border: none; padding: 10px 20px; color: white; cursor: pointer; }
                  </style>
              </head>
              <body>
              <div class="box">
                  <h2>AWS 3-Tier Enterprise Lab</h2>
                  <p>Served From Instance ID: <span class="highlight">\$INSTANCE_ID</span></p>
                  <p>Availability Zone: <span class="highlight">\$AVAILABILITY_ZONE</span></p>
                  <hr>
                  <h3>Submit Info to RDS</h3>
                  <form method="POST">
                      Name: <input type="text" name="name" required><br>
                      Email: <input type="email" name="email" required><br>
                      <input type="submit" value="Submit Data">
                  </form>
                  <p style="color: green;"><b><?php echo \$msg; ?></b></p>
              </div>
              </body>
              </html>
              EOP

              rm -f /var/www/html/index.html
              sed -i 's/index index.html/index index.php index.html/g' /etc/nginx/sites-available/default
              sed -i 's/#location ~ \\.php\$/location ~ \\.php\$/g' /etc/nginx/sites-available/default
              sed -i 's/#\tinclude snippets\/fastcgi-php.conf;/\tinclude snippets\/fastcgi-php.conf;/g' /etc/nginx/sites-available/default
              sed -i 's/#\tfastcgi_pass unix:\/var\/run\/php\/php7.4-fpm.sock;/\tfastcgi_pass unix:\/var\/run\/php\/php8.1-fpm.sock;/g' /etc/nginx/sites-available/default
              sed -i '/location ~ \\.php\$/,/}/s/#//' /etc/nginx/sites-available/default
              systemctl restart nginx
              EOF
  )
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  target_group_arns   = [aws_lb_target_group.tg.arn]
  vpc_zone_identifier = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
}

# ==========================================
# 5. OUTPUTS
# ==========================================

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}
