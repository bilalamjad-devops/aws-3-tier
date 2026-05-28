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


- NAT gateway is placed in a public subnet.
     - 1 NAT gateway only serves 1 availability zone.
     - 2nd NAT gateway only servers 2nd availability zone.


- AWS requires you to provide a list of at least two Subnet IDs from different Availability Zones for the RDS instance.
