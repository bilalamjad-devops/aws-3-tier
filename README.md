# aws-3-tier

In this project, we are using:

```bash
Terraform
VPC
EC2 Auto Scaling
ALB
RDS
Public + private subnets
```

```bash
Internet
   │
ALB (public)
   │
EC2 Auto Scaling (private)
   │
RDS (private)
```

```bash
Tier 1
ALB public

Tier 2
EC2 Auto Scaling private

Tier 3
RDS private
```


vpc/main.tf

```tf

```
