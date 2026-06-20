# BLEA FSx for ONTAP Use Cases

> BLEA (Baseline Environment on AWS) guest system use cases: Enterprise file storage with Amazon FSx for NetApp ONTAP

## Overview

This repository develops CDK use case templates for [Baseline Environment on AWS (BLEA)](https://github.com/aws-samples/baseline-environment-on-aws). It provides 4 use cases leveraging Amazon FSx for NetApp ONTAP.

## Use Cases

| Spec | Directory | Description | Target |
|------|-----------|-------------|--------|
| A | `blea-guest-fsxn-data-analytics-sample` | NFS → S3 AP → Glue/Athena analytics | BLEA |
| B | `guest-fsxn-cyber-resilience-sample` | TPS + ARP + SnapLock + Air-gapped Vault | BLEA for FSI |
| G | `blea-guest-fsxn-flexcache-sample` | FlexCache distributed access acceleration | BLEA |
| H | `blea-guest-fsxn-modernization-sample` | 5 compute patterns with shared storage | BLEA |

## Spec A: Data Analytics (PR #1304 Submitted)

FSx for ONTAP + S3 Access Point + Glue Crawler + Athena SQL analytics pattern.

```
FSx for ONTAP (NFS) → S3 Access Point → Glue Crawler → Athena SQL
```

## Spec B: Cyber Resilience (FISC Compliant)

Multi-layered ransomware defense. Multi-account architecture.

```
TPS (admin-undeletable) + ARP/AI (auto-detection) + SnapLock (WORM)
+ Air-gapped Vault (separate account) + automatic network isolation
```

## Spec G: FlexCache Distributed Access

File access acceleration between headquarters (origin) and branch offices (cache).

```
Origin FSx for ONTAP ←VPC Peering→ Cache FSx for ONTAP (FlexCache)
  HQ Users                  Branch Users (local SSD performance)
```

## Spec H: Modernization Platform

Shared storage foundation for VMware/on-premises migration. 5 compute patterns.

```
FSx for ONTAP (Shared Storage)
├── EC2 ASG (NFS mount)
├── ECS Fargate (S3 AP)
├── EKS (Trident CSI)
├── Lambda (S3 AP)
└── AWS Batch (NFS + Spot)
```

## Development

```bash
# Install dependencies
npm ci

# Build all specs
npm run build

# Test all specs
npm test

# CDK Synth for individual spec
cd usecases/blea-guest-fsxn-data-analytics-sample
npx cdk synth
```

## Status

| Spec | Implementation | Tests | Deployment Verified | PR |
|------|---------------|-------|--------------------|----|
| A | ✅ | 14 pass | ✅ E2E complete | PR #1304 |
| B | ✅ | 13 pass | ✅ 49 resources | — |
| G | ✅ | 12 pass | Budget-dependent | — |
| H | ✅ | 10 pass | ✅ 41 resources | — |

## Shared Modules

The `shared/` directory contains reusable resources across all specs:

- `shared/lambda/ontap-custom-resource/` — ONTAP REST API client
- `shared/templates/` — tsconfig, jest.config, cdk.json templates
- `shared/docs/` — Deployment verification template

## Contribution Targets

- **BLEA**: `aws-samples/baseline-environment-on-aws` (Spec A, G, H)
- **BLEA for FSI**: `aws-samples/baseline-environment-on-aws-for-financial-services-institute` (Spec B)

## License

MIT-0
