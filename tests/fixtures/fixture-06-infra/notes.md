# Manual verification — fixture 06

After running `/infra` with args "fastapi-pg-redis do dev+prod doppler", verify:

## Layout
- [ ] All files from expected-files.txt are present
- [ ] modules/ contains 4 subdirectories (compute, database, cache, networking)
- [ ] envs/ contains dev/ and prod/

## Tier 1: Critical (all must pass)
- [ ] TF-C1: `envs/prod/backend.tf` uses DO Spaces S3 backend (NOT `backend "local"`)
- [ ] TF-C1: bootstrap instructions in README explain how to create the Spaces bucket before `terraform init`
- [ ] TF-C2: every `required_providers` block pins provider version with `~>`
- [ ] TF-C3: `.gitignore` contains `*.tfvars` AND `!*.tfvars.example`
- [ ] TF-C3: `*.tfvars.example` files contain only `<placeholder>` values, no real secrets
- [ ] TF-C4: every resource block has `tags` including env, project, managed_by
- [ ] K8S-C1 through K8S-C4: N/A (Terraform target, not K8s)
- [ ] SEC-C1: any output with connection string / password has `sensitive = true`

## Tier 2: Important
- [ ] TF-I1: every `variable` has `description` and `type`
- [ ] TF-I2: every `output` has `description`
- [ ] SEC-I1: README has "Secret rotation" section describing Doppler rotation
- [ ] SEC-I2: IAM / DO tokens use least-privilege (not *)
- [ ] README-I1: README has init, plan, apply commands for both envs

## Doppler wiring
- [ ] Doppler CLI install is in cloud-init.yaml
- [ ] Service is launched via `doppler run -- <cmd>` in systemd unit
- [ ] README documents `doppler login`, `doppler setup`, `doppler secrets set`

## README quality
- [ ] Prerequisites section (Terraform, doctl, Spaces keys, Doppler)
- [ ] Dev and Prod sections with full command sequences
- [ ] Destroy section with "dev only" warning
- [ ] Outputs section listing what `terraform output` prints

## Refusal paths
- [ ] If user asks for `envs/prod/backend.tf` with `backend "local"`, skill REFUSES and explains TF-C1
- [ ] If user tries to put a real token in `.tfvars` (not .example), skill REFUSES and explains TF-C3

## Failures (fill in if any)
