# デザインレビュー: ペルソナ別フィードバック

> レビュー日: 2026-06-03
> 対象: 4つの Spec デザインドキュメント (A, B, G, H)
> レビュワー: SA Persona Review Board (Persona 1-9)

---

## Persona 2: Storage Specialist レビュー (Storage Specialist レンズ)

### Spec A: fsxn-data-analytics

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | S3 AP の `fileSystemIdentity` で `UNIX_USER: nobody` を使用しているが、これは全ファイルを nobody 権限で読み取ることを意味する。本番環境では適切なユーザーマッピング設計が必要。UID/GID の制御方針を明記すべき |
| **P0** | FSx for ONTAP と S3 AP の**スループット共有**について未記載。NFS/SMB クライアントと S3 AP アクセスは同一ファイルシステムのスループットを共有する。Glue Crawler 実行中に NFS クライアントが影響を受ける可能性がある |
| **P1** | CloudWatch メトリクス `StorageCapacityUtilization` は FSx for ONTAP ネイティブメトリクスとして存在するか要確認。FSx for ONTAP の CloudWatch メトリクスは限定的（`FileServerDiskThroughputBalance`, `CPUUtilization` 等）。カスタムメトリクス収集が必要な場合がある |
| **P1** | volume サイズ 102400 MiB (100GB) が devParameter だが、ボリュームサイズとファイルシステムストレージ容量 (1024 GiB) の関係が不明。FSx for ONTAP では volume は thin provisioned であり、FS 容量は全ボリュームの合計実使用量で消費される。この設計の意味を明記すべき |
| **P2** | FabricPool AUTO ポリシーの tiering minimum cooling days のデフォルト値（31日）について言及がない。分析用途では頻繁アクセスするため AUTO ではなく SNAPSHOT_ONLY が適切な場合がある |

### Spec B: fsxn-cyber-resilience

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | TPS は「通常ボリュームに適用可能」と research.md に記載されているが、実際の設定は Snapshot Policy の retention period として SnapMirror policy rules に設定する。設定パスが ONTAP REST API のどのエンドポイントかを明確にすべき |
| **P1** | ARP/AI の学習期間（通常 30 日）中の false positive 対応フローが設計に含まれていない。検知イベント発生時に「学習中」か「本番」かを判別するロジックが必要 |
| **P1** | SnapLock Enterprise ボリュームへの Snapshot コピー方法が未設計。SnapVault (SnapMirror with vault policy) による自動コピーが必要だが、これは ONTAP CLI/API 操作であり Custom Resource の追加が必要 |
| **P2** | read-path resilience（Snapshot からの読み取り復旧）と full DR strategy（別リージョンへの SnapMirror）を明確に区別すべき |

### Spec G: fsxn-flexcache-distributed

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | FlexCache の cache hit ratio は ONTAP CloudWatch メトリクスとして**直接提供されない**。ONTAP REST API (`GET /api/storage/flexcache/flexcaches/{uuid}`) から取得する必要がある。カスタムメトリクス収集 Lambda の設計が必要 |
| **P0** | inter-cluster peering に必要なネットワーク要件が不完全。FSx for ONTAP 間の intercluster LIF は**管理用 ENI のプライベート IP** を使用する。Cross-region の場合、Transit Gateway 経由でこの IP に到達可能であることが前提。ルーティング設計の詳細化が必要 |
| **P1** | Write-back モードのデータ損失リスクについて、具体的なシナリオ（cache FSx for ONTAP のAZ障害時）と RPO の見積もりが必要。「ドキュメントに記載」では不十分で、parameter.ts でリスク受容のフラグとして明示すべき |
| **P2** | FlexCache volume は FlexGroup として作成される（複数 constituents）。これにより `ls` 等のディレクトリ一覧のレイテンシ特性が通常 FlexVol と異なる。ドキュメントに注記すべき |

### Spec H: fsxn-modernization-platform

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | ECS Fargate から FSx for ONTAP NFS への接続方法が曖昧。「EFS mount point syntax」と記載しているが、**FSx for ONTAP は EFS ではない**。Fargate の NFS マウントは `EFSVolumeConfiguration` で `fileSystemId` に FSx for ONTAP の DNS 名を指定するのではなく、EC2 起動タイプでの NFS mount が正確。Fargate で FSx for ONTAP NFS を直接マウントする方法を再検証すべき |
| **P1** | iSCSI LUN の設計があるが、iSCSI initiator の設定は EC2 UserData で `iscsiadm` コマンドを実行する必要がある。この operational complexity がデザインに反映されていない |
| **P1** | NFS/SMB/iSCSI/S3AP の4プロトコルが同一 SVM 上で提供される設計だが、SVM 1つで全プロトコルを同時に使うと管理が複雑になる。NFS/S3用 SVM と SMB 用 SVM を分離するパターンも検討すべき |
| **P2** | 500 リソース上限のリスクが記載されているが、全 compute pattern ON 時の概算リソース数が示されていない |

---

## Persona 5: Security Reviewer レビュー (Well-Architected Security Pillar レンズ)

### 全 Spec 共通

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | KMS Key Policy の設計が未記載。CMK を作成するが、key policy で誰が管理できるかが不明。Break-glass role の設計が必要（特に Spec B のサイバーレジリエンス） |
| **P1** | Secrets Manager のローテーション設計（Spec B, G, H）で、ローテーション失敗時のロールバックメカニズムが未設計 |
| **P1** | IAM ロールの信頼ポリシー（Trust Policy）の設計が示されていない。Glue, Lambda, StepFunctions 各サービスの `AssumeRole` 条件が必要 |

### Spec A: fsxn-data-analytics

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Glue Crawler の IAM ロールに `glue:*` と記載されているが、これは過剰権限。`glue:GetDatabase`, `glue:CreateTable`, `glue:UpdateTable`, `glue:BatchGetPartition` 等に絞るべき |
| **P1** | S3 Access Point の IAM Policy 設計が不足。S3 AP には独自のアクセスポリシーを設定でき、IAM ロールの permissions だけでなく AP Policy での制御が必要 |
| **P2** | Athena query results bucket の lifecycle policy（古いクエリ結果の自動削除）が未設計 |

### Spec B: fsxn-cyber-resilience

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | ONTAP REST API 認証情報（fsxadmin パスワード）の初期設定方法が未設計。CDK デプロイ前に手動で Secrets Manager に格納する必要があるのか、CDK が初期値を設定するのかが不明 |
| **P0** | Network Isolation Lambda の IAM ロールが NACL 変更権限を持つが、これ自体が攻撃者に悪用される可能性がある。この Lambda の実行条件を GuardDuty イベントに限定する条件（`aws:SourceArn` 制約等）が必要 |
| **P1** | SCP で `backup:DeleteRecoveryPoint` を Deny しているが、SCP の適用範囲（OU 単位か、アカウント単位か）が未設計 |

### Spec G: fsxn-flexcache-distributed

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Cross-region での ONTAP management API 通信が TLS で暗号化されることを確認すべき。inter-cluster peering の通信は暗号化されるが、management API (443) も SSL/TLS であることを明記 |
| **P2** | Custom Resource Lambda が両方の FSx for ONTAP (origin + cache) の管理エンドポイントにアクセスする。Lambda の VPC 配置（どちらの VPC に置くか）と、もう一方への到達方法の設計が必要 |

---

## Persona 6: Reliability / Operations Reviewer レビュー

### 全 Spec 共通

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | **Runbook が設計に含まれていない**。全アラームに対応する runbook（手順書）を documentation deliverable として明記すべき |
| **P1** | SLO 定義がない。FSx for ONTAP の可用性目標 (99.99% for Multi-AZ)、復旧目標 (RPO/RTO) がデザインに含まれるべき |
| **P1** | CloudFormation スタック更新時の rollback 動作が未検討。FSx for ONTAP は `UPDATE_REPLACE` が発生するとデータ喪失するため、`UpdateReplacePolicy: Retain` の設計が必要 |

### Spec A: fsxn-data-analytics

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | Glue Crawler 失敗時の対応フローが未設計。Crawler がエラーになった場合の通知・リトライ設計が必要 |
| **P1** | FSx for ONTAP ファイルシステムの定期メンテナンスウィンドウ（30分/週）について、Glue Crawler スケジュールとの競合を考慮すべき |

### Spec B: fsxn-cyber-resilience

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | StepFunctions restore workflow の**テスト方法**が「Manual test with 3 accounts」のみ。DR 訓練を定期的に実行するスケジュールと検証手順を設計すべき |
| **P1** | ARP/AI が learning → active に移行するタイミングの operational judgment criteria が未定義。誰がいつ判断するのかを runbook に含めるべき |

### Spec H: fsxn-modernization-platform

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | CapacityManager Lambda のスケーリング上限がない。無限にストレージを拡張し続けるとコスト爆発する。Max capacity を parameter.ts に含めるべき |
| **P2** | EventBridge scheduled task の実行失敗時のリトライポリシーが未設計 |

---

## Persona 7: FinOps / Cost Reviewer レビュー

### Spec A: fsxn-data-analytics

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | **月額コスト見積もりが設計に含まれていない**。dev (SINGLE_AZ, 128MBps, 1TiB) と prod (MULTI_AZ, 512MBps, 2TiB) のそれぞれの概算月額を README に含めるべき |
| **P1** | Athena query results bucket のストレージコスト（クエリのたびに結果が蓄積）について、lifecycle policy での自動削除が cost control として必要 |
| **P2** | Glue Crawler 実行頻度によるコスト影響（DPU時間）の見積もりが必要 |

### Spec B: fsxn-cyber-resilience

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | 3アカウント構成のコスト構造が未記載。Air-gapped Vault のストレージコスト、cross-account backup copy のデータ転送コスト、Restore アカウントの待機コストを明記すべき |
| **P1** | SnapLock Enterprise ボリュームは容量プール階層化（FabricPool）を使用可能か確認。使用不可の場合、SSD ストレージのみでコストが高くなる |

### Spec G: fsxn-flexcache-distributed

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | Cross-region データ転送コストが未記載。FlexCache の cache miss 時にクロスリージョン転送料が発生する。Working set のうち何%が cache miss するかでコストが大きく変動する |
| **P1** | Transit Gateway のコスト（接続料 + データ処理料）vs VPC Peering（データ転送料のみ）の比較が設計内に必要 |
| **P2** | Cache FSx for ONTAP のサイジング指針（working set の何倍を推奨するか）がない |

### Spec H: fsxn-modernization-platform

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | 全 compute pattern ON 時 vs 最小構成時のコスト概算がない |
| **P1** | VPC Interface Endpoint のコスト（各 $7.2/月/AZ × endpoint数）が積み上がる。8 endpoint × 2 AZ = $115/月。これを README に含めるべき |
| **P2** | Batch で Spot を使う場合の中断リスクと、NFS マウント中のジョブへの影響を記載すべき |

---

## Persona 9: QA / Test Automation Lead レビュー

### 全 Spec 共通

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | snapshot テストの asset hash 除外設定 (`jest.config.js`) が設計に含まれていない。BLEA upstream の `jest.config.js` パターン（asset hash 無視）を踏襲する必要がある |
| **P1** | Custom Resource Lambda のユニットテスト方針が不十分。ONTAP REST API の mock 設計（レスポンス fixture）が必要 |
| **P2** | CI/CD パイプラインでの `cdk synth` 実行テストが設計に含まれていない（build.yml で対応可能） |

### Spec B: fsxn-cyber-resilience

| 優先度 | 指摘事項 |
|--------|---------|
| **P0** | Network Isolation Lambda のテストが EventBridge mock のみ。Lambda が実際に NACL を変更する動作の integration test 設計が必要（少なくとも手順を記載） |

### Spec H: fsxn-modernization-platform

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | compute pattern toggle の組み合わせテストが不十分。2^5 = 32 通りすべてをテストするのは現実的でないが、代表的な組み合わせ（最小/最大/EC2のみ/Lambda のみ）を定義すべき |

---

## Persona 1: Partner/SI Reviewer (Kawahara-san レンズ)

### 全 Spec 共通

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | パートナーが顧客に説明する「最初の質問」が明確でない。例: 「御社のファイルサーバーデータを SQL で分析したいですか？」→ Spec A、「管理者アカウントが侵害されてもデータを守りたいですか？」→ Spec B |
| **P1** | PoC 用のクイックスタートガイドがない。パートナーが顧客先で 2 時間以内にデモできるような簡易デプロイ手順を設計に含めるべき |
| **P2** | ユースケース間の選択ガイド（どの顧客にどの Spec を提案するか）のデシジョンツリーが必要 |

---

## Persona 3: Public Sector / Governance Reviewer (Public Sector レンズ)

### Spec B: fsxn-cyber-resilience

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | 地方自治体への適用時、3アカウント構成が「ガバメントクラウド」の利用範囲に適合するか確認が必要。組織構造（教育委員会、議会等）によりアカウント分離の方針が異なる |
| **P1** | TPS/ARP のログが「審査証拠」として利用可能であることを文書化すべき。CloudWatch Logs → S3 → 長期保管 のデータ保全チェーンが必要 |
| **P2** | 「AI 出力 = assistive signal」の原則を ARP/AI に適用: ARP 検知 = 自動隔離トリガーではなく、人間の判断を経るモードも用意すべき |

### Spec G: fsxn-flexcache-distributed

| 優先度 | 指摘事項 |
|--------|---------|
| **P1** | 「キャッシュデータの権威性」について: FlexCache のデータは origin の複製であり、cache 側で改ざんされても origin には影響しないことを明記。逆に、cache 側のデータが「正」ではないことをユーザーに伝える運用設計が必要 |

---

## 改善アクションサマリー

### P0 (ブロッカー) — デザイン修正必須

| # | Spec | 指摘元 | 内容 | 対応方針 |
|---|------|--------|------|---------|
| 1 | A | Storage | S3 AP fileSystemIdentity 設計: nobody は本番不適切 | parameter.ts に `s3ApUnixUser` を追加、本番は適切な UID マッピング設計を記載 |
| 2 | A | Storage | NFS/SMB と S3 AP のスループット共有問題 | 設計に「共有スループット」セクション追加、Crawler スケジューリング推奨を記載 |
| 3 | B | Security | ONTAP 認証情報の初期設定フロー | 「前提条件」セクションに Secrets Manager 手動設定手順を追加 |
| 4 | B | Security | Isolation Lambda の実行条件制約 | IAM ロールに `aws:SourceArn` 条件を追加する設計修正 |
| 5 | B | Reliability | Restore workflow のテスト/DR訓練設計 | EventBridge 定期トリガーによる DR 訓練スケジュールを追加 |
| 6 | G | Storage | FlexCache metrics は ONTAP API 経由のみ | カスタムメトリクス収集 Lambda を設計に追加 |
| 7 | G | Storage | Inter-cluster peering のネットワーク要件詳細化 | intercluster LIF のプライベート IP ルーティング設計を追加 |
| 8 | G | FinOps | Cross-region データ転送コスト未記載 | コスト見積もりセクションを追加 |
| 9 | H | Storage | ECS Fargate から FSx for ONTAP NFS の接続方法再検証 | Fargate は EFS のみ直接サポート。EC2 起動タイプ or ECS Anywhere で NFS、Fargate は S3 AP 経由に修正 |
| 10 | B | FinOps | 3アカウント構成のコスト構造未記載 | コスト見積もりセクションを追加 |

### P1 (重要) — 次フェーズまでに対応

| # | Spec | 指摘元 | 内容 |
|---|------|--------|------|
| 11 | All | Security | KMS Key Policy の break-glass role 設計 |
| 12 | All | Reliability | 全アラームに対する runbook を documentation deliverable に追加 |
| 13 | All | Reliability | SLO 定義を設計に追加 |
| 14 | A | Security | Glue IAM ロールの権限を `glue:*` から最小権限に絞る |
| 15 | A | FinOps | 月額コスト見積もりを README に含める設計追加 |
| 16 | B | Storage | SnapLock ボリュームへの Snapshot コピー方法 (SnapVault) 設計 |
| 17 | B | Storage | ARP 学習期間中の false positive 対応フロー |
| 18 | G | FinOps | TGW vs VPC Peering のコスト比較 |
| 19 | G | Security | Custom Resource Lambda の VPC 配置設計 |
| 20 | H | Reliability | CapacityManager の max capacity 上限追加 |
| 21 | H | FinOps | VPC Endpoint コストの明記 |
| 22 | All | QA | snapshot テスト asset hash 除外設定 |
| 23 | All | Partner | クイックスタートガイド/デモ手順 |
| 24 | B | Public Sector | 審査証拠としてのログ保全チェーン設計 |

### P2 (改善) — ドキュメント/将来対応

省略（上記テーブルの P2 項目は実装フェーズで順次対応）
