# PR Draft: aws-samples/baseline-environment-on-aws-for-financial-services-institute

> Branch: feat/fsxn-cyber-resilience-usecase
> Base: main

---

## Title

`feat: Add FSx for ONTAP cyber resilience use case with FISC compliance`

## Body

### Summary

Adds a new guest system use case demonstrating multi-layered cyber resilience using FSx for NetApp ONTAP's native security features (TPS, ARP/AI, SnapLock), designed for financial institutions under FISC guidelines.

### Changes

- Add `usecases/guest-fsxn-cyber-resilience-sample/` with 3 CDK stacks:
  - **Workload**: FSx for ONTAP + TPS + ARP + SnapLock + Backup + Network Isolation (49 resources)
  - **Data Banker**: Air-gapped Vault with Vault Lock + RAM share
  - **Restore**: StepFunctions automated recovery workflow
- 13 Jest tests (KMS, Multi-AZ, SnapLock, Custom Resources, Backup, EventBridge, Alarms, no IGW/NAT)
- Bilingual documentation (Japanese + English) with FISC mapping

### Architecture Highlights

| Defense Layer | Technology | Protection Level |
|--------------|-----------|-----------------|
| Detection | ARP/AI | Ransomware behavioral detection |
| Immutability | Tamperproof Snapshots | Admin cannot delete within retention |
| WORM | SnapLock Enterprise | Configurable retention (1-7 years) |
| Isolation | Air-gapped Vault | Separate account, Vault Lock |
| Response | GuardDuty → NACL | Automatic network containment |
| Recovery | StepFunctions | RTO < 4 hours |

### Review Checklist

- [x] TypeScript strict mode, no unintentional `any` types
- [x] Follows BLEA for FSI coding patterns
- [x] parameter.ts with dev/prod configurations
- [x] CloudWatch Alarms + SNS for all critical paths
- [x] No real account IDs, secrets, or personal information
- [x] Tests pass (`npm test`)
- [x] CDK synth succeeds for all 3 stacks
- [x] Deployment verified (Workload stack: 49 resources)
- [x] FISC security standards mapped
- [x] cdk-nag AwsSolutions pack applied (0 errors, suppressions documented)

### Testing

```bash
cd usecases/guest-fsxn-cyber-resilience-sample
npm ci
npm test          # 13 tests pass
npx cdk synth     # 3 stacks synthesize
```

### CI/CD

- GitHub Actions: TypeScript build + Jest tests + CDK synth (all specs)
- gitleaks: Secret detection on all pushes/PRs
- zizmor: GitHub Actions security linting
- All third-party Actions pinned to SHA

### Dependencies

- aws-cdk-lib ^2.236.0 (required for CfnS3AccessPointAttachment ONTAP support)
- ONTAP 9.13+ (for ARP/AI support)
- Secrets Manager secret (pre-deployment requirement)

### Blocked Features

- **SnapVault replication** (`enableSnapVault` toggle): Creates SnapMirror vault relationship from production volume to SnapLock volume. Disabled by default because ONTAP management endpoint DNS may not be resolvable during initial stack creation (timing issue). Enable in a subsequent `cdk deploy` after FSx for ONTAP is fully AVAILABLE. The construct and Lambda handler are fully implemented.
- Cross-account deployment verification (requires 3 separate accounts)
