# デプロイ検証チェックリスト テンプレート

> Spec: [SPEC_NAME]
> ステータス: テンプレート（コピーして各 Spec で使用）
> ベース: Spec A (fsxn-data-analytics) の実証済みチェックリスト

## 使い方

1. このファイルを `usecases/<usecase-name>/doc/deployment-verification.md` にコピー
2. `[PLACEHOLDER]` を Spec 固有の値に置換
3. Spec 固有の検証項目を追加
4. 検証完了後、結果を `doc/verification-results/` に保存

---

## 1. デプロイ前チェック (共通)

| # | チェック | コマンド | 期待値 | 結果 |
|---|---------|---------|--------|------|
| 1 | AWS CLI 認証 | `aws sts get-caller-identity` | 正しいアカウント ID | [ ] |
| 2 | CDK Bootstrap | `aws cloudformation describe-stacks --stack-name CDKToolkit` | 存在 | [ ] |
| 3 | Node.js >= 20 | `node --version` | v20+ | [ ] |
| 4 | npm install | `npm ci` | exit 0 | [ ] |
| 5 | TypeScript build | `npm run build` | exit 0 | [ ] |
| 6 | Jest tests | `npm test` | 全 PASS | [ ] |
| 7 | CDK synth | `npx cdk synth` | テンプレート生成 | [ ] |

## 2. デプロイ実行 (共通)

```bash
npx cdk deploy --all --require-approval never
```

### 既知の注意点 (steering/fsxn-deployment-lessons.md より)

- [ ] SINGLE_AZ_1 時に `routeTableIds` が含まれていないこと
- [ ] S3 AP の `fileSystemIdentity.type` が `UNIX` or `WINDOWS` であること（NOT `UNIX_USER`）
- [ ] Slack workspace が未認可の場合、Chatbot パラメータを空にしていること
- [ ] CfnVolume `sizeInMegabytes` が string 型で渡されていること
- [ ] Lake Formation 権限が CDK に組み込まれていること（手動 CLI 不要）

## 3. 共通リソース確認

| # | リソース | 確認方法 | 期待値 | 結果 |
|---|---------|---------|--------|------|
| 1 | CloudFormation Stack | `describe-stacks` | CREATE_COMPLETE | [ ] |
| 2 | FSx for ONTAP FileSystem | `describe-file-systems` | AVAILABLE | [ ] |
| 3 | FSx for ONTAP ONTAP Version | 同上 → OntapVersion | >= 9.17.1 | [ ] |
| 4 | KMS 暗号化 | FSx for ONTAP → KmsKeyId | CMK ARN あり | [ ] |
| 5 | VPC IGW なし | `describe-internet-gateways` | 0 件 | [ ] |
| 6 | VPC NAT なし | `describe-nat-gateways` | 0 件 | [ ] |

## 4. [SPEC 固有の検証項目をここに追加]

(各 Spec でカスタマイズ)

## 5. セキュリティ検証 (共通)

| # | チェック | 確認方法 | 期待値 | 結果 |
|---|---------|---------|--------|------|
| 1 | KMS キーローテーション | KMS → Key → Rotation | 有効 | [ ] |
| 2 | FSx for ONTAP SG 外部アクセス拒否 | SG Rules | 0.0.0.0/0 なし | [ ] |
| 3 | CloudTrail FSx API 記録 | CloudTrail → `fsx:` | 記録あり | [ ] |

## 6. クリーンアップ (共通)

```bash
npx cdk destroy --all --require-approval never
```

RETAIN リソースの手動削除:
```bash
aws fsx delete-volume --volume-id [VOL_ID] --ontap-configuration '{"SkipFinalBackup":true}'
aws fsx delete-storage-virtual-machine --storage-virtual-machine-id [SVM_ID]
aws fsx delete-file-system --file-system-id [FS_ID] --ontap-configuration '{"SkipFinalBackup":true}'
aws kms schedule-key-deletion --key-id [KEY_ID] --pending-window-in-days 7
```

## 7. 検証結果サマリー

| カテゴリ | 合計 | OK | NG | SKIP |
|---------|------|----|----|------|
| デプロイ前 | 7 | | | |
| リソース確認 | 6+ | | | |
| Spec 固有 | [N] | | | |
| セキュリティ | 3 | | | |
| クリーンアップ | 3 | | | |
| **合計** | | | | |

### 判定
- [ ] PASS / [ ] PASS with conditions / [ ] FAIL
