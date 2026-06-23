# BLEA 貢献提案: Role-Archetype レビューシミュレーション

> 日付: 2026-06-20
> 対象: コンピュート × FSx for ONTAP 協業に基づく追加貢献候補
> 方式: Role-based archetype レビュー (3 ラウンド) + upstream 受け入れ基準分析

---

## Part A: Upstream 受け入れ基準分析

### BLEA リポジトリの設計原則（公開情報から抽出）

| 基準 | 根拠 |
|------|------|
| 単一スタック、独立デプロイ可能 | 既存3ユースケースすべてがこの構造 |
| parameter.ts による設定管理 | BLEA v3 の標準パターン |
| TypeScript strict mode | 全ユースケース共通 |
| CloudWatch + SNS + Chatbot 監視 | ガバナンスベースとの一貫性 |
| Snapshot + assertion テスト | 全ゲストシステムサンプルに存在 |
| バイリンガルドキュメント (JA primary + EN) | README パターンに一致 |
| 独立デプロイ可能（ガバナンスベースとの疎結合） | アーキテクチャ図に明示 |
| MIT-0 ライセンス互換 | CONTRIBUTING.md に明記 |
| `aws-cdk-lib` のみ依存（外部コンストラクトライブラリ不可） | 既存パターンから推定 |
| Custom Resource は最小限 | 既存ユースケースは全て CloudFormation native |
| セマンティックバージョニングはガバナンスベースのみ | README に明記。ゲストサンプルは破壊的変更の対象 |

### PR マージ要件（CONTRIBUTING.md + 観察）

1. Issue を先に起こして設計議論 → メンテナの興味確認
2. Fork → 変更を focused に保つ（フォーマット変更と機能追加を混ぜない）
3. ローカルテスト通過
4. CI 自動テスト通過
5. 会話に参加し続ける

### 未回答の質問（PR #1304 が2週間以上レビュー待ち）

- メンテナのレスポンス頻度は低い（dependabot PR も溜まっている）
- 新機能 PR への明確な Accept/Reject の判断基準は公開されていない
- FSx for ONTAP を使ったゲストシステムサンプルの前例はないが、FSx for ONTAP は AWS フルマネージドサービスであり、既存の ECS/EC2/Serverless ユースケースが特定 AWS サービスを利用しているのと同列。技術的な受け入れ障壁はない

---

## Part B: Role-Archetype レビュー

### レビューボード構成（15 ロール）

| # | ロール | 視点 |
|---|--------|------|
| 1 | BLEA Maintainer | リポジトリ設計整合性、メンテナンス負荷 |
| 2 | AWS SA (Well-Architected) | WAF 5 Pillars 準拠 |
| 3 | Security Reviewer | IAM、ネットワーク、暗号化 |
| 4 | Cost Optimization Specialist | コスト見積もり精度、削減策 |
| 5 | Compute Specialist (EC2/ECS/EKS) | インスタンス設計、Graviton、Spot |
| 6 | Storage Specialist (FSx for ONTAP) | ストレージ設計、ONTAP 固有知見 |
| 7 | FSI Compliance Reviewer | FISC、金融規制 |
| 8 | Partner/SI Engineer | 導入容易性、PoC 支援 |
| 9 | CDK Specialist | コンストラクト設計、L1/L2/L3 判断 |
| 10 | DevOps / SRE | 運用性、モニタリング、自動復旧 |
| 11 | Networking Specialist | VPC 設計、VPC Peering、TGW |
| 12 | Data Analytics Engineer | Glue/Athena/Lake Formation 設計 |
| 13 | AI/ML Engineer | 推論/学習パイプラインとの統合 |
| 14 | Open Source Community Member | 再利用性、ドキュメント品質 |
| 15 | Japanese Public Sector SA | 自治体要件、政府クラウド適合 |

---

## Round 1: 初期フィードバック

### 対象提案の要約

| # | 提案 | 状態 |
|---|------|------|
| 既存A | Data Analytics (FSx for ONTAP + S3 AP + Glue + Athena) | PR #1304 提出済み |
| 既存B | Cyber Resilience (TPS + ARP + SnapLock) | PR #1308 draft |
| 既存G | FlexCache distributed | PR #1308 draft |
| 既存H | Modernization (5 compute patterns) | PR #1309 draft |
| 新1 | Graviton + FSx for ONTAP コスト最適化 | 提案段階 |
| 新2 | Spot + バッチ処理 | 提案段階 |
| 新3 | EKS + Trident CSI + AI/ML | 提案段階 |

---

### 1. BLEA Maintainer レンズ

> **Topic** (BLEA Maintainer lens): ユースケース数とメンテナンス負荷

**フィードバック:**
- 一度に 4 つの新ユースケース (A/B/G/H) + 追加 3 つは多すぎる。既存の BLEA は 3 ゲストシステムサンプルのみ。一気に7つ追加すると CDK バージョンアップ時のメンテナンス負荷が倍増する
- **Spec A (Data Analytics)** が最も BLEA の既存パターンに近い（CloudFormation native、Custom Resource なし）。まずこれ1つをマージし、反応を見るべき
- Spec B/G は Custom Resource (Lambda + ONTAP REST API) を含む。BLEA の既存パターンは CloudFormation native のみだが、ONTAP REST API によるボリューム設定は FSx for ONTAP 固有の運用要件であり、Custom Resource の利用は合理的。メンテナへの説明では「CloudFormation が未サポートの ONTAP レイヤー設定を補完するもの」と位置づけるべき
- Spec H の 5 compute pattern toggle は複雑。「1 stack, 1 purpose」の原則から外れる可能性

**推奨:**
- Spec A に集中。他は Spec A がマージされてから順次提出
- 新提案 (Graviton/Spot/EKS AI) は独立リポジトリ or `blea-fsxn-usecase` に留め、BLEA upstream への追加提案はしない（まず1つ通す）

---

### 2. AWS SA (Well-Architected) レンズ

> **Topic** (Well-Architected lens): 信頼性とコスト最適化

**フィードバック:**
- Graviton 提案は **コスト最適化の柱** に直接貢献する。BLEA のコスト見積もり表にインスタンスファミリー別の比較を含めると説得力が上がる
- Spot 提案は **信頼性の柱** との緊張がある。中断耐性の設計（チェックポイント、Spot 枯渇時のフォールバック）が必須
- 全提案に **マルチ AZ 考慮**が入っているか確認。FSx for ONTAP Multi-AZ は自動 failover だが、Compute 側の設計（ASG multi-AZ、EKS node group の AZ 分散）も含めるべき

**推奨:**
- 新提案にはそれぞれ WAF レビュー結果の要約セクションを追加
- コスト見積もりに Graviton vs x86 の比較行を追加

---

### 3. Security Reviewer レンズ

> **Topic** (Security lens): Custom Resource の攻撃面

**フィードバック:**
- Spec B/G の Custom Resource Lambda が ONTAP REST API を呼ぶ。認証情報（FSx for ONTAP の管理パスワード）を Secrets Manager に保存し、Lambda から取得する設計は正しいが、Lambda の IAM ロールが `secretsmanager:GetSecretValue` を持つ → **最小権限の原則**として ARN 制約を必ず付けること
- EKS + Trident 提案: CSI driver が privileged container として動作する。Node のセキュリティコンテキスト制約 (PSP/PSA) を明記すべき
- Spot 提案: Spot 中断通知を EventBridge で受ける場合、EventBridge ルールの条件が特定のインスタンスグループに絞られているか

**推奨:**
- IAM ポリシーの Resource 制約を全 Lambda に適用（`*` 禁止）
- Security Hub の AwsSolutions パックによる cdk-nag 検証結果を PR に含める

---

### 4. Cost Optimization Specialist レンズ

> **Topic** (Cost lens): Graviton 提案の ROI 明確化

**フィードバック:**
- Graviton 提案の価値は明確。ただし「20-40% 削減」は一般論。FSx for ONTAP + NFS の文脈で Graviton EC2 が実際に同等性能を出せるかの **ベンチマーク根拠**が必要
- NFSv4.1 over Graviton の fio/iozone ベンチマーク結果があると dev.to 記事としても価値が高い
- EKS + Trident: Karpenter によるノード自動スケーリングのコストメリットを試算に含めるべき

**推奨:**
- Graviton ベンチマーク（fio 4K random read/write、128K sequential）を実施し、結果を doc/ に追加
- コスト比較表に「年間想定コスト」列を追加（月額だけでなく）

---

### 5. Compute Specialist レンズ

> **Topic** (Compute lens): Graviton 互換性と Spot 設計

**フィードバック:**
- Graviton 提案: arm64 AMI の選定が重要。Amazon Linux 2023 ARM が推奨。NFS ユーティリティ (`nfs-utils`) の arm64 パッケージは問題なし
- Spot 提案: **容量最適化アロケーション戦略** (capacity-optimized) を使うべき。lowest-price は中断率が高い
- Spec H の Batch pattern: Graviton 対応は `FARGATE_SPOT` compute environment で ARM64 を指定するだけ。CDK で `computeResources.allocationStrategy` を明示すべき
- EKS 提案: `CfnCluster` (L1) ではなく `Cluster` (L2) を使ったほうがメンテナンスコストが低い。kubectlLayer の問題は CDK v2.150+ で解消済み

**推奨:**
- Spec H の EC2 pattern を Graviton 対応にアップグレード: `ec2.InstanceType.of(ec2.InstanceClass.M7G, ...)` + ARM64 AMI
- EKS は L2 Construct への移行を検討（BLEA の CDK version が `^2.236.0` なら可能）

---

### 6. Storage Specialist レンズ

> **Topic** (Storage Specialist lens): NFS パフォーマンスチューニング

**フィードバック:**
- Graviton + NFS: `nconnect=16` オプションが Graviton インスタンスで特に効果的（マルチコアを活かせる）。ただし nconnect は NFSv4.1 + Linux kernel 5.3+ が必要。AL2023 Graviton なら問題なし
- FlexCache + Graviton: キャッシュ読み取りワークロードで Graviton の高メモリ帯域が効く。cache hit ratio が高いワークロードほど効果大
- Spot + FSx for ONTAP: FSx for ONTAP 側は影響なし（クライアントが中断するだけ）。ただし NFS の `hard` mount オプションにより、EC2 復帰時に自動再接続される

**推奨:**
- mount オプションに `nconnect=16` を追加（Graviton 固有の最適化として記載）
- FlexCache ユースケースの「Graviton branch office server」パターンを doc に追加

---

### 7. FSI Compliance Reviewer レンズ

> **Topic** (FSI Compliance lens): 金融向けワークロードの適合性

**フィードバック:**
- BLEA for FSI が公開されていない以上、FISC マッピングを BLEA 本体 PR に含めるのは過剰
- ただし Spec B (Cyber Resilience) の SnapLock + TPS は金融向けの最重要パターン。FISC 技 XX 条への対応表は **独立ドキュメント** として `doc/reference-arc-*` に置くのは適切
- Graviton 提案: 金融ワークロードでの Graviton 採用は進んでいる（市場データ処理、リスク計算）。FISC 固有の制約はない

**推奨:**
- BLEA 本体 PR では FISC 言及を控え、金融向けガイダンスは `blea-fsxn-usecase` リポジトリの参照アーキテクチャドキュメントに限定
- Spec A PR #1304 から「Government Cloud」セクションを独立ドキュメントに移動（PR の focused nature を保つため）

---

### 8. Partner/SI Engineer レンズ

> **Topic** (Partner/SI lens): 案件適用の容易さ

**フィードバック:**
- 「30分で動く PoC」手順が最重要。parameter.ts の dev 設定でそのまま `cdk deploy` → 動作確認までのステップ数を最小化
- Graviton 提案: 既存顧客が x86 から移行する際の **検証チェックリスト**（アプリ互換性確認 → ベンチマーク → 切替）が欲しい
- 5 compute pattern は選択肢が多すぎて顧客が迷う。**デシジョンツリー**（doc/usecase-selection-guide.md に既にあるが、Graviton/Spot の判断軸を追加）

**推奨:**
- 各提案に「Quick PoC (15 min)」セクションを追加
- Graviton 移行チェックリスト（5 ステップ）を作成

---

### 9. CDK Specialist レンズ

> **Topic** (CDK Specialist lens): コンストラクト設計の適切さ

**フィードバック:**
- Spec H の toggle pattern は CDK の `Condition` ではなく TypeScript の `if` で実装すべき（CDK best practice）。現状の実装は正しい
- Graviton 対応は parameter.ts に `instanceArchitecture: 'ARM64' | 'X86_64'` を追加するだけで実現可能。既存の Spec H EC2 construct に1プロパティ追加
- `aws-cdk-lib` の `^2.236.0` 制約: upstream BLEA は `2.219.0` → `2.260.0` へ更新 PR (#1313) が出ている。マージされれば互換

**推奨:**
- Graviton 対応は Spec H の `parameter.ts` に `instanceArch` プロパティを追加する最小変更で実装
- BLEA upstream の aws-cdk-lib バージョンアップ (#1313) がマージされるのを待ってから PR を最終化

---

### 10. DevOps / SRE レンズ

> **Topic** (SRE lens): 運用自動化の欠如

**フィードバック:**
- FlexCache metrics Lambda (Spec G Task 3) と CapacityManager Lambda (Spec H Task 9) が未実装。これらがないと「デプロイしたけど運用できない」状態になる
- Graviton 提案: Graviton EC2 の OS パッチ適用は SSM Patch Manager で自動化すべき。AL2023 + SSM の組み合わせを推奨
- Spot 中断時の自動ドレイン（ECS の場合 `ECS_ENABLE_SPOT_INSTANCE_DRAINING=true`）を実装に含めるべき

**推奨:**
- Spec G/H の未実装 Lambda を優先完了してから新提案に着手
- Graviton 提案に SSM Patch Manager construct を含める

---

### 11-15: 追加レンズ（要約）

> **Topic** (Networking lens): VPC Peering vs TGW の判断基準を明確化。同一リージョン内は Peering、cross-region は TGW と明記。Graviton 提案にネットワーク変更は不要。

> **Topic** (Data Analytics lens): Athena の CTAS / Iceberg テーブル化のガイダンスを将来追加。Glue Crawler のスケジュールと FSx for ONTAP メンテナンスウィンドウの競合を README に注記。

> **Topic** (AI/ML lens): EKS + Trident + SageMaker Training の連携パスは BLEA 本体には過剰。独立サンプルリポジトリとして設計し、BLEA からはリンクのみ。

> **Topic** (OSS Community lens): README の「Architecture」セクションに Mermaid 図を使用すると GitHub 上で直接レンダリングされ読みやすい。PNG は fallback として残す。

> **Topic** (Public Sector SA lens): 政府クラウド (ISMAP) 準拠の前提条件を明記。FSx for ONTAP は東京リージョンで利用可能だが、ISMAP 認定済みサービスリストでの確認を推奨。

---

## Round 1 対応方針

| フィードバック | 対応 | 優先度 |
|--------------|------|--------|
| 一度に7つは多すぎる → Spec A に集中 | ✅ 同意。PR #1304 のマージに全力 | P0 |
| Spec A から Government Cloud セクション分離 | ✅ 独立ドキュメントに移動 | P1 |
| Graviton は Spec H の最小拡張として実装 | ✅ parameter.ts に1プロパティ追加 | P1 |
| 未実装 Lambda (G-Task3, H-Task9) を先に完了 | ✅ 新提案より優先 | P1 |
| Graviton ベンチマーク実施 | △ 時間次第。結果なしでも提案は可能 | P2 |
| EKS L2 Construct 移行 | △ BLEA upstream CDK version 次第 | P2 |
| Spot 中断ドレイン実装 | △ Spot 提案を進める場合に対応 | P3 |
| FISC マッピングは独立ドキュメント | ✅ 既に対応済み | - |

---

## Round 2: 対応後の再レビュー

### 改善実施内容

1. **戦略変更**: BLEA upstream への追加提案は凍結。PR #1304 (Spec A) のマージに集中
2. **Graviton 対応**: Spec H の `parameter.ts` に `instanceArchitecture` プロパティを追加（`blea-fsxn-usecase` リポジトリ内で先行実装）
3. **新提案の位置づけ**: Graviton/Spot/EKS AI は `blea-fsxn-usecase` リポジトリの追加 Spec として設計。BLEA upstream 提出は Spec A マージ後に判断

### Round 2 フィードバック

> **Topic** (BLEA Maintainer lens): 戦略変更は適切。1つのPR が通る実績を作ることが最重要。PR #1304 にメンテナから返事がない場合、Issue #1303 にリマインドコメントを追加すべき。2-3週間反応がなければ polite bump は妥当。

> **Topic** (Compute Specialist lens): `instanceArchitecture` パラメータの追加は最小侵入的で良い。デフォルト値は `ARM64` (コスト最適化) にすべきか `X86_64` (互換性重視) にすべきか明確にすること。推奨: BLEA upstream PR では `X86_64` デフォルト（既存との互換性）、`blea-fsxn-usecase` では `ARM64` デフォルト（コスト最適化をデモ）。

> **Topic** (Partner/SI lens): PR #1304 がマージされない状況が続くなら、`blea-fsxn-usecase` を独立した aws-samples 提案として位置づけ直すのも手。BLEA の umbrella に入らなくても、独立 CDK サンプルとして価値がある。

> **Topic** (Security lens): PR #1304 のレビューで指摘されそうな点を先回り対応すべき。特に: VPC Flow Logs の有効化（Gov Cloud セクションに入れたが、base pattern にも入れるべきか）、S3 AP の deny policy (BucketOwnerEnforced) の明示。

---

## Round 2 対応方針

| フィードバック | 対応 |
|--------------|------|
| PR #1304 リマインド | Issue #1303 に進捗コメントを追加（6/20 時点で2.5週間経過） |
| instanceArchitecture デフォルト値 | X86_64 (upstream 互換) / ARM64 (blea-fsxn-usecase) で分離 |
| 独立 aws-samples 化の検討 | Fallback plan として準備（BLEA umbrella が通らない場合） |
| VPC Flow Logs / S3 AP deny policy | PR #1304 に反映済み（Government Cloud compliance として追加済み） |

---

## Round 3: 最終確認

### BLEA Maintainer レンズ

> PR #1304 は BLEA の既存パターンに最も合致しており、CloudFormation native、Custom Resource なし、parameter.ts パターン準拠。マージの技術的障壁は低い。メンテナの反応待ちが唯一のブロッカー。

### 最終判定

| ロール | 判定 | コメント |
|--------|------|---------|
| BLEA Maintainer | ⚠️ CONDITIONAL | メンテナ反応待ち。技術的には Ready |
| Well-Architected SA | ✅ | WAF 5 Pillars カバー済み |
| Security | ✅ | cdk-nag 対応済み、最小権限 |
| Cost | ✅ | 見積もり含む、Graviton 拡張準備済み |
| Compute | ✅ | Graviton 拡張パス明確 |
| Storage | ✅ | NFS/S3 AP dual access 設計適切 |
| FSI | ✅ | FISC 参照は独立ドキュメント |
| Partner/SI | ✅ | Quick PoC 手順あり |
| CDK | ✅ | パターン準拠、L2 中心 |
| SRE | ⚠️ | G-Task3, H-Task9 未実装（Spec A には影響なし） |
| Networking | ✅ | 設計適切 |
| Analytics | ✅ | Glue/Athena 設計検証済み |
| AI/ML | N/A | 独立リポジトリとして切り出し |
| OSS | ✅ | Mermaid + PNG、MIT-0 互換 |
| Public Sector | ✅ | Gov Cloud セクション対応済み |

---

## 結論と次のアクション

### 即時アクション（今週）

1. **Issue #1303 に進捗コメント追加** — polite bump + 「追加質問があればお答えします」
2. **PR #1304 の自己レビュー** — Security / CDK specialist フィードバックを反映済みか最終確認
3. **Spec G Task 3 (FlexCache metrics Lambda)** 実装完了 — SRE レンズ指摘対応

### 短期アクション（Spec A マージ後）

4. **Graviton 拡張** — Spec H に `instanceArchitecture` 追加、ARM64 ベンチマーク実施
5. **PR #1308 (FlexCache) を Ready 化** — draft → ready に変更
6. **dev.to 記事**: 「FSx for ONTAP + S3 AP で Zero-ETL データ分析」（Spec A の内容を記事化）

### 中期アクション（Spec A + 1つマージ後）

7. **Graviton + Spot バッチ処理パターン** — Spec H 拡張として `blea-fsxn-usecase` に追加
8. **EKS + Trident AI/ML パターン** — 独立 aws-samples リポジトリとして設計開始
9. **ワークショップ資料作成** — Compute チーム協業の成果物として

### Fallback（BLEA upstream マージが進まない場合）

10. `blea-fsxn-usecase` を独立 aws-samples として公開申請
11. BLEA への依存を外し、standalone CDK サンプルとして再パッケージ

---

## ワークショップ/ラウンドテーブル向け推奨テーマ

Compute チーム協業の観点から、以下が即座に価値を出せるテーマ:

| テーマ | 対象者 | 準備状況 |
|--------|--------|---------|
| FSx for ONTAP + EC2 (Graviton): NFS 共有ストレージの性能とコスト最適化 | SA、顧客 | Spec H + ベンチマーク追加で可 |
| FSx for ONTAP + EKS + Trident: コンテナ永続ストレージのベストプラクティス | SA、開発者 | 新規設計必要 |
| FSx for ONTAP + S3 AP: ファイルデータの Zero-ETL 分析 | SA、データエンジニア | Spec A で即提供可 |
| FlexCache: 拠点間ファイル共有の高速化 | SA、インフラエンジニア | Spec G で即提供可 |
| Cyber Resilience: ランサムウェア対策（TPS + SnapLock + Air-gapped Vault） | SA、セキュリティ担当 | Spec B で即提供可 |
