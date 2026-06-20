# デプロイ検証レポート: FSx for ONTAP Data Analytics

> ステータス: **テンプレート（未実施）**
> 検証日: YYYY-MM-DD
> 検証者: -
> リージョン: ap-northeast-1
> アカウント: (parameter.ts の env 設定に従う)

---

## 1. 検証環境

### 所要時間見積もり

| フェーズ | 見積もり時間 | 備考 |
|---------|-------------|------|
| デプロイ前チェック | 10 分 | ローカル確認のみ |
| CDK Deploy | 30-45 分 | FSx for ONTAP 作成に ~30分 |
| リソース確認 | 15 分 | Console/CLI 確認 |
| テストデータ準備・投入 | 15 分 | EC2 経由または DataSync |
| 機能動作確認 | 30 分 | Crawler 実行 + Athena クエリ |
| セキュリティ検証 | 10 分 | Console 確認 |
| クリーンアップ | 30 分 | FSx for ONTAP 削除に ~20分 |
| **合計** | **約 2.5 - 3 時間** | |

### コスト影響

- FSx for ONTAP 最小構成 (128MBps, 1TiB): 約 $0.70/時間
- 検証全体 (3時間): 約 $2.10 + VPC Endpoint + Glue 実行費
- **1日放置した場合**: 約 $17/日
- **クリーンアップ忘れリスク**: 月末に ~$500 請求

> ⚠️ **重要**: 検証完了後は当日中にクリーンアップを実行してください。

### 検証結果の保管

検証完了後、本ファイルの記入済みコピーを以下に保管：
- `doc/verification-results/YYYY-MM-DD-verification.md`
- Git にコミットして証跡として保持
- PR 提出時に参照リンクとして添付

| 項目 | 値 |
|------|-----|
| AWS アカウント ID | `parameter.ts` の設定値 |
| リージョン | ap-northeast-1 |
| CDK バージョン | `npx cdk --version` の出力 |
| Node.js バージョン | `node --version` の出力 |
| パラメータセット | devParameter (SINGLE_AZ_1, 128MBps, 1024GiB) |
| デプロイ開始時刻 | YYYY-MM-DD HH:MM:SS JST |
| デプロイ完了時刻 | YYYY-MM-DD HH:MM:SS JST |
| 所要時間 | 分 |

---

## 2. デプロイ前チェック

### 2.1 前提条件確認

| # | チェック項目 | コマンド | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | AWS CLI 認証 | `aws sts get-caller-identity` | アカウント ID が返る | [ ] OK / [ ] NG |
| 2 | CDK Bootstrap 済み | `aws cloudformation describe-stacks --stack-name CDKToolkit` | スタック存在 | [ ] OK / [ ] NG |
| 3 | Node.js バージョン | `node --version` | >= 20.x | [ ] OK / [ ] NG |
| 4 | npm install 完了 | `npm ci` | exit 0 | [ ] OK / [ ] NG |
| 5 | TypeScript ビルド | `npm run build` | exit 0 | [ ] OK / [ ] NG |
| 6 | テスト通過 | `npm test` | 全テスト PASS | [ ] OK / [ ] NG |
| 7 | CDK Synth | `npx cdk synth` | テンプレート生成 | [ ] OK / [ ] NG |

### 2.2 コスト確認

| # | チェック項目 | 確認内容 | 結果 |
|---|------------|---------|------|
| 1 | 月額概算理解 | devParameter で ~$500/月 であることを確認 | [ ] 確認済み |
| 2 | クリーンアップ予定 | 検証完了後の削除タイミングを決定 | 予定日: _____ |

---

## 3. デプロイ実行

### 3.1 CDK Deploy

```bash
npx cdk deploy --all --require-approval never
```

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | CloudFormation スタック作成成功 | AWS Console → CloudFormation | CREATE_COMPLETE | [ ] OK / [ ] NG |
| 2 | スタックリソース数 | CloudFormation → Resources タブ | 36 リソース (概算) | 実測: ___ |
| 3 | デプロイ所要時間 | CloudFormation → Events (最初 → 最後) | 30-60 分 (FSx for ONTAP 作成に時間) | 実測: ___ 分 |

### 3.2 エラー発生時の記録

```
エラー内容: (なし / あれば記載)
原因分析: 
対応策: 
```

---

## 4. リソース作成確認

### 4.1 FSx for ONTAP

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | ファイルシステム状態 | `aws fsx describe-file-systems` | Lifecycle: AVAILABLE | [ ] OK / [ ] NG |
| 1b | **ONTAP バージョン** | 同上 → OntapConfiguration.OntapVersion | 9.17.1 以上 (S3 AP 要件) | [ ] OK / [ ] NG |
| 2 | デプロイタイプ | 同上 → OntapConfiguration.DeploymentType | SINGLE_AZ_1 | [ ] OK / [ ] NG |
| 3 | スループット | 同上 → OntapConfiguration.ThroughputCapacity | 128 | [ ] OK / [ ] NG |
| 4 | ストレージ容量 | 同上 → StorageCapacity | 1024 | [ ] OK / [ ] NG |
| 5 | KMS 暗号化 | 同上 → KmsKeyId | CMK ARN あり | [ ] OK / [ ] NG |
| 6 | SVM 状態 | `aws fsx describe-storage-virtual-machines` | Lifecycle: CREATED | [ ] OK / [ ] NG |
| 7 | ボリューム状態 | `aws fsx describe-volumes` | Lifecycle: CREATED | [ ] OK / [ ] NG |
| 8 | ストレージ効率化 | 同上 → OntapConfiguration.StorageEfficiencyEnabled | true | [ ] OK / [ ] NG |
| 9 | FabricPool Tiering | 同上 → OntapConfiguration.TieringPolicy.Name | AUTO | [ ] OK / [ ] NG |

> ⏱️ **待機時間**: FSx for ONTAP ファイルシステム作成完了まで約 **30分**。`Lifecycle: CREATING` → `AVAILABLE` を確認してから次に進むこと。

```bash
# 確認コマンド
aws fsx describe-file-systems --query 'FileSystems[?Tags[?Key==`Environment` && Value==`Development`]].[FileSystemId,Lifecycle,StorageCapacity,OntapConfiguration.DeploymentType,KmsKeyId]' --output table
```

### 4.2 S3 Access Point

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | AP 状態 | `aws fsx describe-s3-access-point-attachments` (※) | Lifecycle: AVAILABLE | [ ] OK / [ ] NG |
| 2 | AP 名 | 同上 | fsxn-analytics-dev | [ ] OK / [ ] NG |
| 3 | ボリューム関連付け | 同上 → OntapConfiguration.VolumeId | FSx for ONTAP Volume ID | [ ] OK / [ ] NG |

> ※ API が利用不可の場合は AWS Console → FSx → S3 Access Points で確認
> ⏱️ **待機時間**: S3 AP 作成完了まで約 **5分**。`CREATING` → `AVAILABLE` を確認。

### 4.3 ネットワーク

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | VPC 作成 | AWS Console → VPC | CIDR 10.0.0.0/16 | [ ] OK / [ ] NG |
| 2 | サブネット数 | VPC → Subnets (フィルタ: VPC ID) | 2 (Private Isolated) | [ ] OK / [ ] NG |
| 3 | IGW なし | VPC → Internet Gateways | 0 件 | [ ] OK / [ ] NG |
| 4 | NAT なし | VPC → NAT Gateways | 0 件 | [ ] OK / [ ] NG |
| 5 | VPC Endpoint: S3 | VPC → Endpoints (S3) | 存在 (Gateway) | [ ] OK / [ ] NG |
| 6 | VPC Endpoint: Glue | VPC → Endpoints (Glue) | 存在 (Interface) | [ ] OK / [ ] NG |
| 7 | VPC Endpoint: Athena | VPC → Endpoints (Athena) | 存在 (Interface) | [ ] OK / [ ] NG |

### 4.4 セキュリティグループ

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | FSx for ONTAP SG: NFS ポート | SG → Inbound Rules | TCP 2049 from 10.0.0.0/16 | [ ] OK / [ ] NG |
| 2 | FSx for ONTAP SG: SMB ポート | 同上 | TCP 445 from 10.0.0.0/16 | [ ] OK / [ ] NG |
| 3 | FSx for ONTAP SG: 外部アクセス拒否 | 同上 | 0.0.0.0/0 からのルールなし | [ ] OK / [ ] NG |
| 4 | Glue SG: 自己参照 | SG → Inbound Rules | Self-referencing rule 存在 | [ ] OK / [ ] NG |

### 4.5 データ分析リソース

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | Glue Database | AWS Console → Glue → Databases | fsxn_analytics_db 存在 | [ ] OK / [ ] NG |
| 2 | Glue Crawler | Glue → Crawlers | fsxn-data-crawler 存在 | [ ] OK / [ ] NG |
| 3 | Crawler スケジュール | 同上 → Schedule | cron(0 2 * * ? *) | [ ] OK / [ ] NG |
| 4 | Athena Workgroup | Athena → Workgroups | fsxn-analytics 存在 | [ ] OK / [ ] NG |
| 5 | Workgroup 設定強制 | 同上 → Settings | EnforceWorkGroupConfiguration: true | [ ] OK / [ ] NG |
| 6 | 結果バケット暗号化 | S3 → バケット → Properties | SSE-KMS 有効 | [ ] OK / [ ] NG |
| 7 | 結果バケット公開拒否 | S3 → Permissions | Block all public access: ON | [ ] OK / [ ] NG |

### 4.6 モニタリング

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | SNS Topic | SNS → Topics | AlarmTopic 存在 | [ ] OK / [ ] NG |
| 2 | Email Subscription | SNS → Subscriptions | Pending confirmation / Confirmed | [ ] OK / [ ] NG |
| 3 | Chatbot 設定 | Chatbot Console | Slack チャネル設定済み | [ ] OK / [ ] NG |
| 4 | CW Alarm: Throughput | CloudWatch → Alarms | ThroughputUtilization alarm 存在 | [ ] OK / [ ] NG |
| 5 | CW Alarm: CPU | 同上 | CPUUtilization alarm 存在 | [ ] OK / [ ] NG |
| 6 | CW Alarm: Storage | 同上 | StorageCapacity alarm 存在 | [ ] OK / [ ] NG |

---

## 5. 機能動作確認

### 5.0 テストデータ準備

> ⚠️ テストデータには**個人情報・機密情報を含まないこと**。合成データまたは公開データセットを使用すること。

**テストデータ仕様:**

| 項目 | 値 |
|------|-----|
| ファイル形式 | CSV (UTF-8, カンマ区切り) |
| ファイル数 | 3 ファイル以上 |
| 1ファイルサイズ | 1 MB - 10 MB |
| 合計サイズ | 10 MB - 50 MB |
| スキーマ例 | `id,name,category,value,timestamp` |
| 配置パス | `/data/sample/` (FSx for ONTAP junction path 配下) |

**テストデータ作成例:**

```bash
# CSV テストデータ生成 (Python)
python3 -c "
import csv, random, datetime
with open('/tmp/sample_data.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['id', 'name', 'category', 'value', 'timestamp'])
    for i in range(100000):
        writer.writerow([
            i,
            f'item_{i:06d}',
            random.choice(['A', 'B', 'C', 'D']),
            round(random.uniform(1.0, 1000.0), 2),
            (datetime.datetime(2025, 1, 1) + datetime.timedelta(minutes=i)).isoformat()
        ])
print('Generated: /tmp/sample_data.csv')
"
```

**データ投入方法:**
- 方法A: VPC 内テスト EC2 から NFS マウント → ファイルコピー
- 方法B: AWS DataSync (オンプレ → FSx for ONTAP)
- 方法C: FSx for ONTAP ONTAP CLI で `volume file` コマンド（管理エンドポイント経由）

### 5.1 FSx for ONTAP NFS マウント確認（オプション: EC2 からの確認）

> FSx for ONTAP が AVAILABLE になった後、VPC 内から NFS マウントが可能であることを確認。
> 本ユースケースでは EC2 を含まないため、テスト用の一時 EC2 を使用するか、スキップ。

| # | チェック項目 | 手順 | 結果 |
|---|------------|------|------|
| 1 | NFS マウント | テスト EC2 から `mount -t nfs <fsxn-dns>:/data /mnt` | [ ] OK / [ ] SKIP |
| 2 | ファイル書き込み | `echo "test" > /mnt/test.csv` | [ ] OK / [ ] SKIP |

### 5.2 S3 Access Point 経由のアクセス確認

| # | チェック項目 | コマンド/手順 | 期待値 | 結果 |
|---|------------|-------------|--------|------|
| 1 | S3 AP ListObjects | `aws s3api list-objects-v2 --bucket <s3-ap-alias>` | ファイル一覧が返る | [ ] OK / [ ] NG |
| 2 | S3 AP GetObject | `aws s3api get-object --bucket <s3-ap-alias> --key <path> /tmp/out` | ファイル取得成功 | [ ] OK / [ ] NG |
| 3 | S3 AP GetObject レイテンシ | `time aws s3api get-object --bucket <s3-ap-alias> --key <path> /tmp/out` | 実測: ___ 秒 | 記録 |

> ※ S3 AP alias は CloudFormation Output または `aws fsx` コマンドから取得

### 5.3 Glue Crawler 実行

| # | チェック項目 | コマンド/手順 | 期待値 | 結果 |
|---|------------|-------------|--------|------|
| 1 | Crawler 手動実行 | `aws glue start-crawler --name fsxn-data-crawler` | 成功 | [ ] OK / [ ] NG |
| 2 | Crawler 完了待機 | `aws glue get-crawler --name fsxn-data-crawler` → State | READY (完了後) | [ ] OK / [ ] NG |
| 3 | テーブル検出 | `aws glue get-tables --database-name fsxn_analytics_db` | テーブル 1 件以上 | [ ] OK / [ ] NG |
| 4 | Crawler 所要時間 | CloudWatch Logs | 実測: ___ 分 | 記録 |

### 5.4 Athena クエリ実行

| # | チェック項目 | 手順 | 期待値 | 結果 |
|---|------------|------|--------|------|
| 1 | サンプルクエリ実行 | Athena Console → `SELECT * FROM <table> LIMIT 10` | 結果行 10 件 | [ ] OK / [ ] NG |
| 2 | Workgroup 使用確認 | クエリ実行時に fsxn-analytics workgroup 選択 | 結果が S3 バケットに出力 | [ ] OK / [ ] NG |
| 3 | クエリ実行時間 | Athena → Query history | 実測: ___ 秒 | 記録 |
| 4 | データスキャン量 | Athena → Query history | 実測: ___ MB | 記録 |

### 5.5 モニタリング動作確認

| # | チェック項目 | 手順 | 期待値 | 結果 |
|---|------------|------|--------|------|
| 1 | メトリクス表示 | CloudWatch → Metrics → AWS/FSx | FSx for ONTAP メトリクスが表示される | [ ] OK / [ ] NG |
| 2 | アラーム状態 | CloudWatch → Alarms | 全アラーム OK 状態 | [ ] OK / [ ] NG |
| 3 | SNS テスト発行 | `aws sns publish --topic-arn <arn> --message "test"` | メール受信 | [ ] OK / [ ] NG |
| 4 | **アラーム動作テスト** | `aws cloudwatch set-alarm-state --alarm-name <throughput-alarm> --state-value ALARM --state-reason "Verification test"` | SNS 通知受信 (Email/Slack) | [ ] OK / [ ] NG |
| 5 | **アラーム復帰確認** | `aws cloudwatch set-alarm-state --alarm-name <throughput-alarm> --state-value OK --state-reason "Reset after test"` | アラーム OK に戻る | [ ] OK / [ ] NG |

---

## 6. セキュリティ検証

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | インターネット非接続 | VPC → Route Tables → ルート確認 | 0.0.0.0/0 ルートなし | [ ] OK / [ ] NG |
| 2 | KMS 暗号化 (FSx for ONTAP) | FSx Console → File System → Encryption | CMK 使用 | [ ] OK / [ ] NG |
| 3 | KMS 暗号化 (S3) | S3 Console → Bucket → Encryption | SSE-KMS | [ ] OK / [ ] NG |
| 4 | KMS キーローテーション | KMS Console → Key → Rotation | 有効 | [ ] OK / [ ] NG |
| 5 | IAM 最小権限 (Glue) | IAM → Role → Policies | glue:* 不使用 | [ ] OK / [ ] NG |
| 6 | S3 パブリックアクセス | S3 → Bucket → Permissions | Block all: ON | [ ] OK / [ ] NG |
| 7 | FSx for ONTAP SG 外部拒否 | EC2 → Security Groups | 0.0.0.0/0 ルールなし | [ ] OK / [ ] NG |
| 8 | **CloudTrail 記録確認** | CloudTrail → Event history → `fsx:` フィルタ | FSx for ONTAP API コール記録あり | [ ] OK / [ ] NG |
| 8b | **CloudTrail 具体 API** | 以下の API コールが記録されていることを確認: `CreateFileSystem`, `CreateStorageVirtualMachine`, `CreateVolume`, `CreateAndAttachS3AccessPoint` | 各 API 記録あり | [ ] OK / [ ] NG |
| 8c | **Glue API 記録** | CloudTrail → `glue:` フィルタ: `CreateDatabase`, `CreateCrawler`, `StartCrawler` | 各 API 記録あり | [ ] OK / [ ] NG |
| 9 | **S3 AP 外部アクセス否定テスト** | 別リージョン or 別アカウントのCredentials で `aws s3api list-objects-v2 --bucket <s3-ap-alias>` | AccessDenied | [ ] OK / [ ] NG / [ ] SKIP |
| 10 | **2層認可テスト** | ファイル権限 `chmod 600` のファイルに対して S3 AP 経由 GetObject を実行 | AccessDenied (Layer 2 拒否) | [ ] OK / [ ] NG / [ ] SKIP |

### 否定テスト詳細

S3 AP が意図しないアクセスを拒否することの確認：

```bash
# 別プロファイル（別アカウント or 権限なしユーザー）で実行
aws s3api list-objects-v2 --bucket <s3-ap-alias> --profile <unauthorized-profile>
# 期待結果: An error occurred (AccessDenied)
```

> 別アカウントがない場合は SKIP とし、理由を記録すること

---

## 7. クリーンアップ

### 7.1 CDK Destroy

```bash
npx cdk destroy --all --require-approval never
```

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | スタック削除成功 | CloudFormation → Stacks | DELETE_COMPLETE | [ ] OK / [ ] NG |
| 2 | RETAIN リソース残存 | FSx Console | FSx for ONTAP ファイルシステム残存 | [ ] OK / [ ] NG |
| 3 | RETAIN リソース残存 | KMS Console | CMK 残存 (削除保留) | [ ] OK / [ ] NG |

### 7.2 RETAIN リソース手動削除

> ⚠️ 検証完了後、コスト発生を止めるために手動削除が必要

```bash
# FSx for ONTAP ボリューム削除
aws fsx delete-volume --volume-id <volume-id> --ontap-configuration '{"SkipFinalBackup":true}'

# FSx for ONTAP SVM 削除
aws fsx delete-storage-virtual-machine --storage-virtual-machine-id <svm-id>

# FSx for ONTAP ファイルシステム削除
aws fsx delete-file-system --file-system-id <fs-id> --ontap-configuration '{"SkipFinalBackup":true}'

# KMS キー削除予約 (7日後に完全削除)
aws kms schedule-key-deletion --key-id <key-id> --pending-window-in-days 7
```

| # | チェック項目 | 確認方法 | 期待値 | 結果 |
|---|------------|---------|--------|------|
| 1 | FSx for ONTAP 削除 | FSx Console | DELETING → なし | [ ] OK / [ ] NG |
| 2 | KMS 削除予約 | KMS Console | Pending deletion | [ ] OK / [ ] NG |
| 3 | S3 バケット空 + 削除 | S3 Console | バケットなし | [ ] OK / [ ] NG |

---

## 8. 検証結果サマリー

| カテゴリ | 合計 | OK | NG | SKIP |
|---------|------|----|----|------|
| デプロイ前チェック | 7 | | | |
| リソース作成確認 | 29 | | | |
| 機能動作確認 | 17 | | | |
| セキュリティ検証 | 9 | | | |
| クリーンアップ | 6 | | | |
| **合計** | **68** | | | |

### 判定

- [ ] **PASS**: 全チェック OK（NG/SKIP なし）
- [ ] **PASS with conditions**: 軽微な SKIP あり（機能に影響なし）
- [ ] **FAIL**: NG 項目あり（要修正）

### 特記事項

```
(検証中に発見した事項、パラメータ調整、想定外の動作等を記載)
```

### コスト実績

| 項目 | 予測 | 実績 |
|------|------|------|
| デプロイ～クリーンアップ期間 | | 時間 |
| 発生コスト概算 | | USD |

---

## 9. 検証環境の再現手順（他者向け）

本検証を再現するための最小手順：

```bash
# 1. リポジトリクローン
git clone <repo-url>
cd usecases/blea-guest-fsxn-data-analytics-sample

# 2. 依存パッケージインストール
npm ci

# 3. parameter.ts 編集（env のコメントアウト解除、アカウント/リージョン設定）

# 4. CDK Bootstrap (初回のみ)
npx cdk bootstrap

# 5. デプロイ
npx cdk deploy --all --require-approval never

# 6. FSx for ONTAP 起動待ち (約30分)
aws fsx describe-file-systems --query 'FileSystems[0].Lifecycle'

# 7. テストデータ投入 (NFS マウントまたは AWS DataSync)

# 8. Glue Crawler 実行
aws glue start-crawler --name fsxn-data-crawler

# 9. Athena クエリ
# AWS Console → Athena → Workgroup: fsxn-analytics → SELECT * FROM <table> LIMIT 10

# 10. クリーンアップ
npx cdk destroy --all
# + RETAIN リソースの手動削除
```
