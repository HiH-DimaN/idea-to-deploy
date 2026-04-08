# Fixture 06: /infra Terraform generation for fastapi-pg-redis on DigitalOcean

## User says

> Настрой terraform для FastAPI-проекта с PostgreSQL и Redis на DigitalOcean. Две среды: dev и prod. Секреты через Doppler.

## Why this fixture exists

Tests `/infra` end-to-end for the most common preset (`fastapi-pg-redis`) on the most common target (`do`). Exercises:
- Preset detection from user input
- Environment layout (dev + prod) with separate backends
- Remote tfstate enforcement for prod (TF-C1)
- Provider version pinning (TF-C2)
- .gitignore correctness (TF-C3)
- Resource tagging (TF-C4)
- Doppler secrets wiring
- README generation with exact init/plan/apply commands

## Expected generated layout

```
infra/
├── modules/
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── cloud-init.yaml
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cache/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── networking/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── envs/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── backend.tf                  # local backend OK for dev
│   │   └── terraform.tfvars.example
│   └── prod/
│       ├── main.tf
│       ├── backend.tf                  # MUST use DO Spaces S3-compatible backend
│       └── terraform.tfvars.example
├── .gitignore                          # includes *.tfstate, *.tfvars (with .example exception)
└── README.md                           # init/plan/apply commands for both envs
```

## Expected report

- **TF-C1 PASS** — prod uses DO Spaces remote backend
- **TF-C2 PASS** — digitalocean provider pinned with `~>`
- **TF-C3 PASS** — .gitignore excludes *.tfvars, allows *.tfvars.example
- **TF-C4 PASS** — every resource has env/project/managed_by tags
- **SEC-C1 PASS** — outputs with secrets marked `sensitive = true`
- **SEC-I1** — README includes a "Secret rotation" section (via Doppler dashboard)
- **README-I1 PASS** — README has init/plan/apply commands
- **Final status: PASSED** (or PASSED_WITH_WARNINGS if a Nice-to-have fails)

## Doppler wiring check

- [ ] `doppler_token_ref` is a variable, not a literal
- [ ] cloud-init installs Doppler CLI and runs the app under `doppler run`
- [ ] README documents `doppler setup` and `doppler run` workflow
