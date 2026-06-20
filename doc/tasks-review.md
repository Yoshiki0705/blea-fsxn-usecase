# タスクリスト レビュー: ペルソナ別フィードバック

> レビュー日: 2026-06-03
> 対象: 4 Spec のタスクリスト (tasks.md)
> デザインレビュー P0 修正反映済みの状態でレビュー

---

## Persona 2: Storage Specialist レビュー (Storage Specialist レンズ)

### Spec A: fsxn-data-analytics (11 tasks)

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 4 (FsxnStorage): `routeTableIds` を CfnFileSystem に渡す設計だが、Multi-AZ の場合は VPC 内の**全ルートテーブル**を指定する必要がある。Networking Construct から全 private subnet のルートテーブル ID を export すべき |
| **P1** | Task 7 (Monitoring): FSx for ONTAP の CloudWatch メトリクスとして `StorageCapacity free < 20%` と記載されているが、FSx for ONTAP のネイティブメトリクスは `StorageCapacityUtilization` (%)。計算方法をタスクに明記すべき |
| **P2** | Task 6 (DataAnalytics): Glue Crawler の S3Target にS3 AP ARN を直接指定する際の形式 (`s3://accesspoint-alias/prefix/`) を確認する検証タスクがない |

### Spec B: fsxn-cyber-resilience (16 tasks)

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 2 (Custom Resource): TPS 有効化の具体的な ONTAP REST API パスが未特定。`PATCH /api/storage/volumes/{uuid}` の body に `snapshot_locking_enabled: true` + `snapshot_lock.retention_period` を設定する形式の確認タスクが必要 |
| **P1** | Task 6 (SnapLock Volume): SnapLock Enterprise ボリュームに本番ボリュームの Snapshot を自動コピーする仕組み（SnapVault）が Task に含まれていない。Custom Resource 追加タスクが必要 |
| **P2** | Task 5 (FsxnProtection): ARP/AI の ONTAP REST API パスは `PATCH /api/storage/volumes/{uuid}` の `anti_ransomware.state` フィールド。具体的な API body を検証タスクに含めるべき |

### Spec G: fsxn-flexcache-distributed (15 tasks)

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 2 (FlexCache Lambda): inter-cluster peering 作成時に必要な「passphrase」パラメータが考慮されていない。origin 側と cache 側の両方で同じ passphrase を使う必要がある |
| **P1** | Task 8 (Cache FSx for ONTAP): 「NO regular volumes」と記載しているが、FlexCache ボリュームの「container aggregate」として最低限の aggregate が必要。Cache FSx for ONTAP のストレージサイジング指針がタスクに不足 |
| **P2** | Task 3 (Metrics Lambda): FlexCache statistics の ONTAP API レスポンス構造の検証タスクがない。`/api/storage/flexcache/flexcaches` のレスポンスフィールドを事前確認すべき |

### Spec H: fsxn-modernization-platform (16 tasks)

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | Task 3 (FsxnStorage): **iSCSI LUN 作成は CfnVolume だけでは不完全**。iSCSI LUN はボリューム作成後に ONTAP CLI/API で `lun create` が必要。Custom Resource タスクの追加が必須 |
| **P1** | Task 3: S3 Access Point を2つ（VPC-origin for Lambda + Internet-origin for Glue）作成する設計だが、1つのボリュームに複数の S3 AP をアタッチできるか要確認。制限がある場合はボリュームを分ける必要がある |
| **P2** | Task 4 (EC2): NFS mount の UserData で `mount -t nfs` コマンドに `-o noresvport,hard,rsize=262144,wsize=262144` オプションを含めるべき。パフォーマンス最適化のベストプラクティス |

---

## Persona 5: Security Reviewer レビュー

### 全 Spec 共通

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Custom Resource Lambda (Spec B, G, H) のランタイムバージョンが指定されていない。Node.js 20.x を明示し、EOL ランタイムを回避するタスクを追加すべき |
| **P1** | Lambda 関数の `ReservedConcurrentExecutions` が未設定。Custom Resource Lambda は 1-2 で十分であり、意図しない並列実行を防止すべき |

### Spec A

| 優先度 | 指摘事項 |
|--------|---------|
| **P2** | Task 6: Athena query results bucket に `aws:SecureTransport` condition (HTTPS-only) の bucket policy が含まれていない |

### Spec B

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 8 (Network Isolation): Rollback Lambda に「MFA 条件」と記載があるが、Lambda 関数に MFA を強制する具体的なメカニズム（IAM policy Condition `aws:MultiFactorAuthPresent`）のタスクが不足 |
| **P1** | Task 11 (Data Banker): SCP の JSON 定義を CDK で作成するか、ドキュメントとして提供するかが曖昧。Organizations SCP は CDK で管理可能だが、管理アカウントからの deploy が必要 |

### Spec G

| 優先度 | 指摘事項 |
|--------|---------|
| **P2** | Task 2: Lambda が 2 つの FSx for ONTAP の管理エンドポイントにアクセスするが、接続先 IP が動的。Secrets Manager に IP/hostname も含めるか、FSx API で動的取得するかをタスクに明記すべき |

---

## Persona 6: Reliability / Operations Reviewer レビュー

### 全 Spec 共通

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | **Runbook タスクが不足**。全 Spec の Monitoring アラームに対応する Runbook（対応手順）が documentation タスクに含まれるべき。Spec B のみ手順書タスクがあるが、A/G/H にもアラーム対応手順が必要 |
| **P1** | CloudFormation スタック更新時の `UpdateReplacePolicy` 設定タスクが明示されていない。FSx for ONTAP FileSystem/Volume に `RETAIN` を設定するタスクはあるが、CDK の `overrideLogicalId` や cfnOptions での制御タスクがない |

### Spec A

| 優先度 | 指摘事項 |
|--------|---------|
| **P2** | Glue Crawler 失敗時の EventBridge ルール（Crawler state change → FAILED → SNS 通知）がタスクに含まれていない |

### Spec B

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 13 (DR Drill): DR 訓練後のクリーンアップ Lambda のタイムアウト設計が必要。FSx for ONTAP 削除は時間がかかる（30分以上）ため、非同期処理 + polling が必要 |

### Spec G

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Origin FSx for ONTAP の定期メンテナンスウィンドウ中に FlexCache が stale read を返すケースの運用ガイダンスが documentation タスクに不足 |

---

## Persona 7: FinOps / Cost Reviewer レビュー

### Spec A

| 優先度 | 指摘事項 |
|--------|---------|
| **OK** | Task 10 (Documentation) に月額コスト見積もりが含まれている。問題なし |

### Spec B

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 15 (Documentation) に「cost estimate (3-account structure)」と記載があるが、具体的な内訳の計算タスクがない。Backup storage costs, cross-account transfer, Lambda execution costs の試算タスクを追加すべき |

### Spec G

| 優先度 | 指摘事項 |
|--------|---------|
| **OK** | デザインレビューで P0 対応済み（cost estimation セクション追加）。タスク 14 (Documentation) にコスト見積もりが含まれている |

### Spec H

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 15 に「Cost estimate (minimum vs full config, VPC Endpoint costs)」とあるが、具体的な見積もり計算タスクがない。AWS Pricing Calculator で試算する検証タスクを追加すべき |
| **P1** | Task 9 (ServerlessOps): CapacityManager に `maxCapacityGiB` ガードが parameter にあるが、**throughput の上限**も設定すべき。throughput 自動拡張は特にコスト影響が大きい（128→256 MBps で月額 +$300） |

---

## Persona 9: QA / Test Automation Lead レビュー

### 全 Spec 共通

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Custom Resource Lambda のテスト fixture（ONTAP API mock レスポンス JSON）を `test/fixtures/` に定義するタスクがない。テスト再現性のために必要 |
| **P1** | `build.yml` GitHub Action での `npx cdk synth` 検証タスクが CI level で含まれていない。全 Spec の Build Verification タスクはローカルのみ。CI integration タスクを追加すべき |

### Spec A

| 優先度 | 指摘事項 |
|--------|---------|
| **OK** | Task 9 のアサーションリストは十分。`glue:*` 不使用の検証が含まれている点が良い |

### Spec B

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 14: 3スタック分のスナップショットテストがあるが、スナップショット更新手順（`npm test -- -u`）のドキュメントタスクがない。マルチスタック構成ではスナップショット管理が複雑になるため |

### Spec H

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Task 14: compute pattern の組み合わせテストが「Full ON / All OFF」の2パターンのみ。最低限「EC2のみ」「Lambdaのみ」「ECS+EKS」の代表パターンを追加すべき |

---

## Persona 1: Partner/SI Reviewer (Kawahara-san レンズ)

### 全 Spec

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | **クイックスタートタスクがない**。パートナーが 2 時間で顧客にデモするための最小デプロイ手順（parameter.ts の最小設定 + `cdk deploy` 一発）を documentation タスクに追加すべき |
| **P2** | ユースケース選択ガイド（デシジョンツリー）がプロジェクト全体の doc/ に必要。個別 Spec のタスクではないが、全体 TODO として記録すべき |

---

## 改善アクションサマリー

### P0 (ブロッカー) — タスク修正必須

| # | Spec | 指摘元 | 内容 | 対応 |
|---|------|--------|------|------|
| 1 | H | Storage | iSCSI LUN 作成に Custom Resource が必要 | Task 3 に iSCSI Custom Resource サブタスク追加 |

### P1 (重要) — タスク追記推奨

| # | Spec | 指摘元 | 内容 |
|---|------|--------|------|
| 2 | A | Storage | routeTableIds の全 private subnet export |
| 3 | A | Storage | FSx for ONTAP CloudWatch メトリクス名の正確な確認タスク |
| 4 | B | Storage | TPS API パス検証タスク追加 |
| 5 | B | Storage | SnapVault (Snapshot → SnapLock コピー) Custom Resource タスク追加 |
| 6 | G | Storage | inter-cluster peering passphrase 考慮 |
| 7 | G | Storage | Cache FSx for ONTAP サイジング指針 |
| 8 | H | Storage | 1ボリュームに複数 S3 AP の可否確認タスク |
| 9 | All | Security | Lambda ランタイムバージョン (Node.js 20.x) 明示 |
| 10 | All | Security | Lambda ReservedConcurrentExecutions 設定 |
| 11 | B | Security | Rollback Lambda の MFA 条件実装方法明確化 |
| 12 | B | Security | SCP デプロイ方法の明確化 |
| 13 | All | Reliability | アラーム対応 Runbook のドキュメントタスク追加 (A/G/H) |
| 14 | B | Reliability | DR Drill クリーンアップの非同期処理設計 |
| 15 | G | Reliability | メンテナンスウィンドウ中の FlexCache 挙動ドキュメント |
| 16 | B | FinOps | 3アカウントコスト試算の具体的計算タスク |
| 17 | H | FinOps | throughput 自動拡張の上限設定 |
| 18 | All | QA | ONTAP API mock fixture の作成タスク |
| 19 | All | QA | CI (build.yml) での cdk synth 検証 |
| 20 | H | QA | compute pattern 代表組み合わせテスト追加 |
| 21 | All | Partner | クイックスタート/デモ手順の documentation タスク |

### 対応方針

P0 (#1) は即座にタスクリストを修正します。P1 の中で特に実装品質に直結するもの (#2-8 Storage, #9-10 Security) もタスクに反映します。その他の P1 は実装フェーズで順次対応可能です。
