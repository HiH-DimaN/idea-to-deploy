# Terraform Template: FastAPI + Postgres + Redis on DigitalOcean

> Skeleton used by `/infra` when the user asks for `fastapi-pg-redis` / `do`. Placeholders in `{{...}}` are replaced at generation time.

## Layout

```
infra/
├── modules/
│   ├── compute/       # droplet for the FastAPI app
│   ├── database/      # managed postgres
│   ├── cache/         # managed redis
│   └── networking/    # VPC, firewall, DNS
├── envs/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── backend.tf         # local or Spaces
│   │   └── terraform.tfvars.example
│   └── prod/
│       ├── main.tf
│       ├── backend.tf         # Spaces REQUIRED
│       └── terraform.tfvars.example
├── .gitignore
└── README.md
```

## modules/compute/main.tf

```hcl
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
  }
}

resource "digitalocean_droplet" "app" {
  name     = "{{project_name}}-${var.environment}-app"
  region   = var.region
  size     = var.size
  image    = "ubuntu-24-04-x64"
  vpc_uuid = var.vpc_uuid
  ssh_keys = var.ssh_key_ids

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    app_image  = var.app_image
    doppler_token = var.doppler_token_ref
  })

  tags = [
    "env:${var.environment}",
    "project:{{project_name}}",
    "managed_by:terraform",
  ]
}

resource "digitalocean_reserved_ip" "app" {
  count  = var.environment == "prod" ? 1 : 0
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "app" {
  count      = var.environment == "prod" ? 1 : 0
  ip_address = digitalocean_reserved_ip.app[0].ip_address
  droplet_id = digitalocean_droplet.app.id
}
```

## modules/database/main.tf

```hcl
resource "digitalocean_database_cluster" "postgres" {
  name       = "{{project_name}}-${var.environment}-pg"
  engine     = "pg"
  version    = "16"
  size       = var.size            # "db-s-1vcpu-1gb" dev, "db-s-2vcpu-4gb" prod
  region     = var.region
  node_count = var.environment == "prod" ? 2 : 1
  private_network_uuid = var.vpc_uuid

  tags = [
    "env:${var.environment}",
    "project:{{project_name}}",
    "managed_by:terraform",
  ]
}

resource "digitalocean_database_db" "app" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "{{project_name}}"
}

resource "digitalocean_database_firewall" "postgres" {
  cluster_id = digitalocean_database_cluster.postgres.id

  rule {
    type  = "droplet"
    value = var.app_droplet_id
  }
}
```

## envs/prod/backend.tf (MANDATORY remote state)

```hcl
terraform {
  backend "s3" {
    endpoint                    = "fra1.digitaloceanspaces.com"
    bucket                      = "{{project_name}}-tfstate"
    key                         = "prod/terraform.tfstate"
    region                      = "us-east-1"   # required placeholder for S3 backend
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    encrypt                     = true
  }
}
```

> **Bootstrap:** the Spaces bucket must exist BEFORE `terraform init`. Create it manually with `doctl compute cdn create --region fra1` or the Spaces UI. Do NOT manage the tfstate backend with Terraform itself (chicken-and-egg).

## .gitignore

```
*.tfstate
*.tfstate.backup
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfvars
!*.tfvars.example
```

## README (generated)

```markdown
# Infrastructure — {{project_name}}

## Prerequisites
- Terraform >= 1.5 (`brew install terraform`)
- `doctl auth init` with a DO API token
- Spaces access key for tfstate: export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
- Doppler CLI if using Doppler secrets backend: `doppler login`

## Dev
cd envs/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan

## Prod (CAREFUL — read every resource change)
cd envs/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan

## Destroy (dev only — NEVER on prod without change window)
terraform destroy

## Outputs
terraform output       # prints app_ip, db_connection_ref, redis_host
```
