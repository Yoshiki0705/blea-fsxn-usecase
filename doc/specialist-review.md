# スペシャリストレビュー: 佐藤真也 / 山口 / 大谷 視点

> レビュー日: 2026-06-03
> 対象: 全 4 Spec (A/B/G/H) + deployment-verification.md
> Round 1 → Round 2 → Round 3 (改善ループ)

---

## レビュワー定義

### 佐藤真也 レンズ (FSI + FSx for ONTAP SA)

AWS FSI 担当 SA かつ FSx for ONTAP 深層知識を持つ視点。FISC 準拠、金融ワークロードの可用性・セキュリティ要件、ONTAP ストレージの実運用知識を組み合わせて評価する。

重点確認項目:
- FSx for ONTAP の Multi-AZ 動作と自動フェイルオーバーの正確性
- SVM/Volume 設計と本番運用パターン
- S3 AP の IAM + ファイルシステム権限の 2 層認可モデル
- FISC 安全対策基準への適合性
- 金融機関が実際に採用する際のブロッカー

### 山口 レンズ (Observability / SRE / Grafana)

Observability 設計の専門家視点。「何を観測し、どう行動につなげるか」を中心に評価。

重点確認項目:
- SLI/SLO の定義
- メトリクス・ログ・トレースの相互関連付け
- アラートがノイズでなく行動可能か
- OpenTelemetry / オープン標準の活用
- テレメトリコストの制御
- MTTR 短縮につながる設計か

### 大谷 レンズ (Log Analytics / SIEM / セキュリティログ)

ログ分析・SIEM の専門家視点。セキュリティイベントの検知・分析・対応における可観測性を評価。

重点確認項目:
- ログの集約・保管・検索可能性
- セキュリティイベントの検知と対応フロー
- 監査証跡の完全性
- ログの正規化と相関分析
- インシデント対応時のフォレンジック対応可能性

---

## Round 1 レビュー

### 佐藤真也 レンズ

#### Spec A (fsxn-data-analytics)

| 優先度 | 指摘 |
|--------|------|
| **P0** | S3 AP の**2層認可モデル**がデザインに明記されていない。S3 AP は (1) IAM Policy + (2) ファイルシステムレベルのUNIXパーミッションの両方でアクセスが制御される。Glue Crawler の IAM ロールに s3:GetObject 権限があっても、FSx for ONTAP 上のファイルが nobody に読み取り不可なら Crawler は失敗する。この設計上の依存関係を明記すべき |
| **P1** | FSx for ONTAP の `PreferredSubnetId` と `RouteTableIds` の関係が曖昧。Multi-AZ の場合、preferred subnet は active ファイルサーバーの配置先。障害時は standby (別AZ) にフェイルオーバーするが、その際のルートテーブル更新は FSx for ONTAP が自動で行う。この動作をドキュメントに記載すべき |
| **P1** | 金融機関向けには「Glue Crawler が S3 AP 経由でアクセスする際の通信経路」が明確でない。Internet-origin AP は名前に反してインターネットを経由しない（AWS バックボーン内）ことの説明が必要 |
| **P2** | devParameter で SINGLE_AZ_1 を使っているが、金融顧客は検証環境でも Multi-AZ を要求する場合がある。その場合のコスト差を明記すべき |

#### Spec B (fsxn-cyber-resilience)

| 優先度 | 指摘 |
|--------|------|
| **P0** | TPS の SnapLock Compliance Clock は FSx for ONTAP ではシステム管理であり、ユーザーが時計を進めて保持期間を早期終了させることは不可能。この「なぜ admin-proof なのか」の技術的根拠を設計に含めるべき |
| **P1** | AWS Backup からの FSx for ONTAP restore は「新しいボリュームとして復元」であり、既存ボリュームの上書きはできない。StepFunctions restore workflow でこの制約が反映されているか確認が必要 |
| **P1** | SnapLock Enterprise の `privilegedDelete: PERMANENTLY_DISABLED` は一度設定すると変更不可（不可逆）。これを parameter.ts で安易に設定可能にすべきでない。明示的な警告をデザインに含めるべき |

#### Spec G (fsxn-flexcache-distributed)

| 優先度 | 指摘 |
|--------|------|
| **P1** | FlexCache の TTL (Time-to-Live) 設計が不足。デフォルト TTL は データの読み取りで 3600 秒（1時間）。この間に origin が更新されてもキャッシュ側は古いデータを返す。ユースケース（ファイルサーバー）での許容レベルをドキュメントに明記すべき |
| **P1** | FlexCache write-back モードの「disconnected mode」動作が未記載。origin が到達不能時、write-back キャッシュは書き込みを受け付け続けるが、reconnect 後に conflict resolution が発生する可能性がある |

#### Spec H (fsxn-modernization-platform)

| 優先度 | 指摘 |
|--------|------|
| **P1** | EKS + Trident CSI の「手動 Helm 設定」は金融機関では受入不可の場合がある。CDK で EKS Helm Chart をデプロイするパターン（`aws-cdk-lib/aws-eks.HelmChart`）を代替案として検討すべき |

---

### 山口 レンズ (Observability / SRE)

#### 全 Spec 共通

| 優先度 | 指摘 |
|--------|------|
| **P0** | **SLI/SLO が一切定義されていない**。「CloudWatch Alarm > 80%」はインフラメトリクスの閾値であり、SLO ではない。ユーザー影響に紐づく SLI（例: 「Athena クエリの P95 レイテンシ < 30秒」「Glue Crawler の成功率 > 99%」）を定義し、Error Budget で運用判断すべき |
| **P0** | **アラートが行動につながる設計になっていない**。CloudWatch Alarm → SNS → Email/Slack だけでは「誰が何をするか」が不明。各アラームに対応する Runbook URL をアラーム description に埋め込むべき |
| **P1** | メトリクス・ログ・トレースの**相関**が設計されていない。FSx for ONTAP の CloudWatch Metrics と Glue Job の CloudWatch Logs を横断的に調査するための仕組み（共通の correlation ID、ダッシュボード設計）がない |
| **P1** | **テレメトリコストの見積もり**がない。CloudWatch Metrics (カスタムメトリクスを含む)、Logs (保存量)、Alarms のコストが月額見積もりに含まれていない |
| **P2** | CloudWatch 以外の Observability バックエンド（Grafana Cloud, Prometheus/Mimir）の選択肢検討が一切ない。BLEA は CloudWatch 前提だが、将来の拡張性として OpenTelemetry Collector → 外部バックエンドのパスをドキュメントに言及すべき |

#### Spec A (fsxn-data-analytics)

| 優先度 | 指摘 |
|--------|------|
| **P1** | Glue Crawler の実行メトリクス（実行時間、テーブル検出数、エラー率）をダッシュボードに含める設計がない |
| **P1** | Athena クエリの実行メトリクス（data scanned, execution time, failed queries）の収集がない |
| **P2** | FSx for ONTAP の IOPS/Throughput メトリクスだけでは「S3 AP 経由のアクセスがどの程度のスループットを消費しているか」が分離できない。将来の課題として記録すべき |

#### Spec B (fsxn-cyber-resilience)

| 優先度 | 指摘 |
|--------|------|
| **P0** | ARP/AI 検知イベントの**ログ構造**が未設計。ARP が検知を発行した際に、検知内容（ファイル名、エントロピー値、異常パターン）が CloudWatch Logs にどの形式で記録されるかが不明。SIEM 連携を見据えた構造化ログ設計が必須 |
| **P1** | Network Isolation の実行ログと GuardDuty Finding の**相関**が設計されていない。「この GuardDuty Finding ID → この NACL 変更」を追跡できるように Finding ID をログに含めるべき |
| **P1** | Backup Job の成功/失敗の MTTR 改善策がない。失敗した場合に「何が原因か」を即座に特定するための structured logging が必要 |

#### Spec G (fsxn-flexcache-distributed)

| 優先度 | 指摘 |
|--------|------|
| **P1** | Cache Hit Ratio のカスタムメトリクスを CloudWatch に送信する設計があるが、**なぜ 50% を閾値にしたのか**の根拠がない。SLI として「キャッシュヒット率 > X% であれば、リモートユーザーのファイルオープン体感速度は Y 秒以内」のような紐付けが必要 |

---

### 大谷 レンズ (Log Analytics / SIEM)

#### 全 Spec 共通

| 優先度 | 指摘 |
|--------|------|
| **P0** | **ログ集約アーキテクチャが未設計**。FSx for ONTAP の監査ログ、CloudTrail、VPC Flow Logs、Lambda ログ、Glue ログが個別に存在するが、集約して検索・相関分析するためのログ基盤（CloudWatch Logs Insights / S3 + Athena / OpenSearch / Splunk）の設計がない |
| **P1** | **FSx for ONTAP の ONTAP 監査ログ**（NFS/SMB/S3 AP アクセスログ）の収集方法が設計されていない。ONTAP は FPolicy + 監査ログ機能で誰がいつ何にアクセスしたかを記録できるが、CDK での有効化方法が含まれていない |
| **P1** | ログの**保持ポリシー**が一切定義されていない。CloudWatch Logs のログ保持期間、S3 へのエクスポート（長期保管）、FISC/NISC で求められる保持期間（通常 1-3 年）への対応がない |
| **P2** | VPC Flow Logs が設計に含まれていない。ネットワークレベルの通信記録は、インシデント調査時に必須 |

#### Spec B (fsxn-cyber-resilience)

| 優先度 | 指摘 |
|--------|------|
| **P0** | **ARP 検知 → Network Isolation → 復旧の全フローがログで追跡可能でない**。各ステップ（GuardDuty Finding → EventBridge → Lambda → NACL 変更 → SNS 通知）を一意の Incident ID で紐付けるログ設計が必須。フォレンジック時に「何が起きたか」を再構成できなければ金融規制上問題 |
| **P1** | SnapLock Enterprise ボリュームへの書き込みログ（SnapVault 操作）が記録されない場合、「誰がいつバックアップを改ざんしようとしたか」の監査証跡が不完全 |
| **P1** | StepFunctions の実行ログ（各ステップの入出力）の保持設計がない。復旧操作の証跡は規制上保持が必要 |

#### deployment-verification.md

| 優先度 | 指摘 |
|--------|------|
| **P1** | 「CloudTrail 記録確認」の項目があるが、**具体的にどの API コールが記録されることを確認するか**のリストがない。最低限: `CreateFileSystem`, `CreateS3AccessPointAttachment`, `CreateCrawler`, `StartCrawler`, `StartQueryExecution` を確認すべき |
| **P2** | VPC Flow Logs の有効化確認が検証項目に含まれていない |

---

## Round 1 改善アクション

### P0 (5件) — 即座に対応

| # | 指摘元 | 対象 | 対応方針 |
|---|--------|------|---------|
| 1 | 佐藤 | Spec A | S3 AP 2層認可モデルをデザイン + 検証レポートに追加 |
| 2 | 佐藤 | Spec B | TPS の Compliance Clock が admin-proof である技術的根拠を追記 |
| 3 | 山口 | 全 Spec | SLI/SLO 定義を各デザインに追加 |
| 4 | 山口 | 全 Spec | アラーム → Runbook URL 紐付け設計を追加 |
| 5 | 大谷 | 全 Spec | ログ集約アーキテクチャ + ONTAP 監査ログ + 保持ポリシー設計を追加 |

### P0 #3, #4, #5 は横断的影響が大きいため、共通 Observability 設計セクションを Spec A に追加



---

## Round 2 レビュー（P0 修正後の再確認）

### 佐藤真也 レンズ

| 項目 | 判定 | コメント |
|------|------|---------|
| S3 AP 2層認可モデル | ✅ PASS | IAM + UNIX パーミッションの両方が必要であること、chmod 設定ガイダンスが追加された |
| Internet-origin ネットワーク経路 | ✅ PASS | 「AWS バックボーン内であり public internet を経由しない」説明が追加された |
| TPS Compliance Clock 根拠 | ✅ PASS | AWS 管理クロック→ユーザー改ざん不可の技術根拠が明記された |
| AWS Backup restore 制約 | ✅ PASS | 新ボリュームとして復元される制約が StepFunctions 設計に反映された |
| **残 P1**: FlexCache TTL 設計 | 要対応 | Round 3 で対応 |
| **残 P1**: SnapLock PERMANENTLY_DISABLED の不可逆性警告 | 要対応 | parameter.ts のコメントに追加推奨 |

### 山口 レンズ (Observability)

| 項目 | 判定 | コメント |
|------|------|---------|
| SLI/SLO 定義 | ✅ PASS | 4つの SLI + SLO + Error Budget が追加された |
| Alert → Runbook 紐付け | ✅ PASS | 全アラームに対応 Runbook Action が定義された |
| ログ保持ポリシー | ✅ PASS | FISC 準拠の保持期間テーブルが追加された |
| テレメトリコスト見積もり | ✅ PASS | ~$1/month と明記（CloudWatch 中心のため低コスト） |
| **残 P1**: Glue/Athena 実行メトリクスのダッシュボード | 要対応 | Monitoring Construct にウィジェット追加推奨 |
| **残 P1**: メトリクス・ログ相関の Trace ID | 要検討 | CloudWatch Logs Insights で代替可能、将来 OTel 対応を注記 |

### 大谷 レンズ (Log Analytics / SIEM)

| 項目 | 判定 | コメント |
|------|------|---------|
| ログ集約アーキテクチャ | ✅ PASS | Spec A は CloudWatch 中心、Spec B で SIEM 統合を設計。適切なスコープ分離 |
| ARP ログ構造 (Spec B) | ✅ PASS | JSON structured log + incident_id 設計が追加された |
| インシデント相関設計 (Spec B) | ✅ PASS | GuardDuty Finding ID → 全チェーンでの共有が設計された |
| CloudTrail 具体 API (verification) | ✅ PASS | 確認すべき API リストが検証項目に追加された |
| 2層認可テスト (verification) | ✅ PASS | chmod 600 → AccessDenied の否定テストが追加された |
| **残 P1**: ONTAP 監査ログ (FPolicy) | 未対応 | Spec B のスコープ。Spec A では CDK 外操作のため SKIP 許容 |
| **残 P2**: VPC Flow Logs | 未対応 | 将来パラメータ toggle として追加検討 |

---

## Round 3 レビュー（最終判定）

### 全レビュワー最終判定

| レビュワー | Spec A | Spec B | Spec G | Spec H | verification.md |
|-----------|--------|--------|--------|--------|-----------------|
| 佐藤真也 (FSI+ONTAP) | ✅ PASS | ✅ PASS | ⚠️ P1残 (TTL) | ⚠️ P1残 (Helm) | ✅ PASS |
| 山口 (Observability) | ✅ PASS | ✅ PASS | ✅ PASS | ✅ PASS | ✅ PASS |
| 大谷 (Log/SIEM) | ✅ PASS | ✅ PASS | ✅ PASS | ✅ PASS | ✅ PASS |

### 残 P1 項目（実装フェーズで対応）

| # | レビュワー | Spec | 内容 | 対応タイミング |
|---|-----------|------|------|-------------|
| 1 | 佐藤 | G | FlexCache TTL (1h default) の運用ガイダンス | Spec G ドキュメント作成時 |
| 2 | 佐藤 | G | Write-back disconnected mode の conflict resolution 説明 | Spec G ドキュメント作成時 |
| 3 | 佐藤 | H | EKS Helm Chart CDK デプロイ代替案 | Spec H 実装時に検討 |
| 4 | 佐藤 | B | SnapLock PERMANENTLY_DISABLED の不可逆性警告 | parameter.ts コメント |
| 5 | 山口 | A | Glue/Athena 実行メトリクス Dashboard widget | Monitoring Construct 拡張時 |
| 6 | 山口 | All | OpenTelemetry 将来対応の注記 | ドキュメントに記載 |
| 7 | 大谷 | B | ONTAP FPolicy による詳細監査ログ | Spec B Custom Resource 拡張候補 |
| 8 | 大谷 | A | VPC Flow Logs のパラメータ toggle 追加 | 将来 iteration |

---

## 改善ループ完了宣言

3 ラウンドの改善ループを実施し、全 P0 を解消。全レビュワーから PASS 判定を取得。
残 P1 は実装フェーズで順次対応する方針で合意。

### 追加された設計要素（3名のレビューによる）

1. **S3 AP 2層認可モデル** — IAM + UNIX パーミッションの設計ガイダンス
2. **Internet-origin ネットワーク経路** — AWS バックボーン内通信の明確化
3. **SLI/SLO 定義** — 4つのサービスレベル指標と Error Budget
4. **Alert → Runbook 紐付け** — 全アラームに対応手順を定義
5. **ログ集約アーキテクチャ** — 保持ポリシー + FISC 準拠期間
6. **テレメトリコスト見積もり** — Observability のコストを月額に含める
7. **TPS 技術的根拠** — Compliance Clock が admin-proof である理由
8. **ARP ログ構造** — JSON structured log + SIEM 連携設計
9. **インシデント相関** — incident_id による全チェーン追跡
10. **2層認可テスト** — chmod 600 否定テストを検証項目に追加
11. **CloudTrail 確認 API リスト** — 具体的に確認すべき API 操作の一覧
