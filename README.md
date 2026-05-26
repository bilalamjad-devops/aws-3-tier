# aws-3-tier

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
