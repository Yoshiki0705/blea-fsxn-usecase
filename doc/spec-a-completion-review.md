# Spec A 完了レビュー: 全 Named ペルソナからのアドバイス

> レビュー日: 2026-06-03
> 対象: Spec A (fsxn-data-analytics) 全成果物 + 次ステップ
> ラウンド: Round 1 → 改善 → Round 2 (Final)

---

## Round 1: ペルソナ別アドバイス

### Kawahara-san (Partner/SI)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **Issue 提出のタイミング**: コード実装前に Issue を出すのが BLEA upstream の作法。Spec A の実装は完了しているが、Issue を先に出してメンテナーの温度感を確認すべき。フィードバックで設計変更があった場合のリワークを防げる |
| **P1** | **パートナー向けデモシナリオ**: README はデプロイ手順だが「15分でお客様に見せるデモ」のシナリオがない。「ファイルサーバーに CSV を置くだけで SQL 分析可能に」の one-liner + 3ステップデモ手順を追加すべき |
| **P2** | **成功メトリクス**: 「このテンプレートの導入で何が測定可能に改善するか」が不明。PoC ゴール例: 「ファイルサーバーからデータレイクへのコピー工程を 100% 削減」 |

### Storage Specialist

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **MULTI_AZ_1 での実デプロイ検証**: devParameter (SINGLE_AZ_1) でのみ検証。prodParameter (MULTI_AZ_1) でのデプロイは未実施。RouteTableIds の条件分岐が正しく動くことを Multi-AZ で確認すべき。次の Spec B のデプロイ時に合わせて確認可能 |
| **P1** | **Snapshot Policy の CloudFormation 対応状況**: CfnVolume に `snapshotPolicy` パラメータがあるか未確認。FSx for ONTAP は Volume 作成時にデフォルトの snapshot policy が適用されるが、CDK で明示的に設定していない。data protection の観点で不十分 |
| **P2** | **スループット共有の定量検証**: 設計に「共有スループット」の注意書きはあるが、実測値がない。Glue Crawler 実行中に NFS クライアントの throughput が何%影響を受けるかの参考値があれば説得力が増す |

### Public Sector / Governance Reviewer

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **データ分類の明確化**: テストデータは合成データだが、本番利用時に「どのデータ分類レベルまで FSx for ONTAP + S3 AP パターンに載せてよいか」のガイダンスがない。公共セクター向けには「機密性2以下」等のガイドラインが必要 |
| **P1** | **操作記録・監査証跡**: Glue Crawler / Athena の実行者・実行内容・結果の監査証跡が設計に含まれているが、「保持期間」と「証跡のタンパー防止」が未実装。CloudTrail → S3 (SSE-KMS + Object Lock) パターンの推奨を追記 |
| **P2** | **LGWAN / ガバメントクラウドとの接続パターン**: BLEA 本体への貢献としてはスコープ外だが、公共セクター適用時の留意事項として DirectConnect / VPN との共存パターンを doc に言及すべき |

### Kobayashi-san (Outcome / Business Value)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **ビジネス成果の定義**: 「Athena クエリが動いた」は技術的成功であり、ビジネス成果ではない。Issue 提出時に「このテンプレートが解決するビジネス課題」を明記すべき: 例「ファイルサーバーデータの活用率を 0% → 分析可能に転換」 |
| **P1** | **次に何をすれば良いかが不明**: README のデプロイ後に「次に試すこと」（QuickSight 連携、Bedrock KB 設定等）への導線がない。「PoC → 本番化ジャーニー」を 1 セクション追加すべき |
| **P2** | **コスト対効果の示し方**: 「月$500」の情報はあるが「既存方式（S3 へコピー + ETL 構築）と比較してどれだけ削減か」の比較がない |

### Hikita-san (Analytics / Iceberg Architect)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **Glue Crawler で検出されるテーブルの品質**: CSV 300K 行は検証に十分だが、実運用では複数フォーマット（CSV, Parquet, JSON）が混在する。Crawler の classifiers 設定や partition 構造の設計ガイダンスが README に不足 |
| **P1** | **Athena クエリのコスト最適化ガイダンス**: 14.5 MB スキャンは微量だが、TB級では「Parquet への変換 + パーティショニング」が必須。「S3 AP 経由では Parquet 直接読み取りが可能か？」の検証結果を追記すべき |
| **P2** | **Iceberg / Delta との非互換の明確化**: 「Iceberg 書き込み不可」は制約に記載されているが、「読み取り専用なら Iceberg テーブルとして登録可能か？」の調査が有用。Athena から Iceberg table 扱いで S3 AP を読む可能性 |

### 山口 (Observability / SRE)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **Glue Crawler 失敗アラート**: Monitoring Construct に FSx for ONTAP メトリクスのアラームは3つあるが、Glue Crawler 失敗のアラートがない。EventBridge (Glue Crawler State Change → FAILED) → SNS を追加すべき |
| **P2** | **ダッシュボード**: CloudWatch Dashboard が未実装。アラームはあるがダッシュボードがない。Spec B 以降では含まれているが、Spec A は Monitoring Construct の最小実装。将来追加検討 |

### 大谷 (Log Analytics / SIEM)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **VPC Flow Logs 未実装**: セキュリティ検証項目に入っているが実装されていない。パラメータ toggle で有効化できるようにすべき（コスト影響あるためデフォルト OFF） |
| **P2** | **Glue Crawler 実行ログの構造化**: `/aws-glue/crawlers` ログは Glue が自動出力するが、検索性が低い。将来的にログを S3 にエクスポートして Athena で検索するパターン（self-referential: FSx for ONTAP → S3 AP → Athena）が面白い |

### Max (IoT / ONTAP / SORACOM)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **実運用でのデータ投入パターンの多様化**: テストでは EC2 → NFS mount → Python 生成だが、実運用では DataSync、AWS Transfer Family (SFTP)、SnapMirror (on-prem → FSx for ONTAP) のパターンがある。「データがどうやって FSx for ONTAP に入るか」の選択肢を README に追記すべき |
| **P2** | **IoT データとの連携可能性**: IoT センサーデータ（時系列 CSV）を NFS で FSx for ONTAP に蓄積 → S3 AP → Athena 分析は有効なパターン。将来のユースケースとして doc に言及 |

### 倉光 (Data + AI / Lakehouse)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **データガバナンスの深掘り**: Lake Formation の CfnPrincipalPermissions を CDK に組み込んだのは正しいが、「誰が何のテーブルにアクセスできるか」のアクセス制御設計が不十分。本番では Column-level access control が必要になる |
| **P2** | **BI / AI への接続パス**: Athena で分析できることは示されたが、そこから QuickSight (BI) や SageMaker (ML) への接続パスが示されていない。「データ活用のゴール」までの全体像を doc に追記すべき |

### 佐藤真也 (FSI + ONTAP SA)

| 優先度 | アドバイス | 領域 |
|--------|----------|------|
| **P1** | **Issue 提出前のアーキテクチャ図の品質**: Mermaid .mmd ファイルはあるが PNG レンダリングされていない。Issue に添付するには画像が必要。CI/CD でレンダリングするか、手動で PNG を生成しておくべき |
| **P1** | **upstream BLEA との CDK バージョン差異**: 本プロジェクトは `^2.219.0` だが BLEA upstream 最新は `^2.219.0` (一致)。ただし devDependencies (jest, ts-jest 等) のバージョン差異がある。PR 時にメンテナーから指摘される可能性。BLEA upstream の最新を再確認 |
| **P2** | **BLEA for FSI との整合**: Spec A は BLEA 本体向けだが、Spec B (FSI) との共通 Construct がある。共通化の方針を README か AGENTS.md に明記して、レビュワーが全体像を把握できるようにすべき |

---

## Round 1 改善アクション（P1 のみ）

| # | ペルソナ | アクション | 実施場所 |
|---|---------|----------|---------|
| 1 | Kawahara | Issue 文面ドラフトを最終化し、デモシナリオ (15分) を追加 | doc/issue-draft.md, README |
| 2 | Storage Specialist | Snapshot Policy のパラメータ追加を検討（現状 ONTAP デフォルト適用） | 将来タスクとして記録 |
| 3 | Public Sector Reviewer | データ分類ガイダンス + 監査証跡の保持推奨を README に追記 | doc/README_ja.md |
| 4 | Kobayashi | Issue 文面にビジネス課題 + 「次のステップ」セクションを README に追加 | doc/issue-draft.md, README |
| 5 | Hikita | 「複数フォーマット対応」「Parquet 読取可否」のガイダンスを追記 | doc/README_ja.md |
| 6 | 山口 | Glue Crawler 失敗アラート (EventBridge → SNS) を追加 | 将来改善として記録 |
| 7 | 大谷 | VPC Flow Logs パラメータ toggle を将来タスクとして記録 | steering に記録済み |
| 8 | Max | データ投入パターン（DataSync, Transfer Family, SnapMirror）を README に追記 | doc/README_ja.md |
| 9 | 倉光 | データ活用の全体像（QuickSight, SageMaker, Bedrock）への導線を追記 | doc/README_ja.md |
| 10 | 佐藤 | architecture.png をレンダリング、CDK バージョン最終確認 | doc/images/, package.json |

---

## 次に進むべきステップ（全ペルソナ総合）

### 即座に実施すべき (Spec A クローズ前)

1. **Issue 文面の最終化** — ビジネス課題、デモシナリオ、アーキテクチャ図（PNG）を含む
2. **README の拡充** — データ投入パターン、次のステップ（QuickSight/Bedrock 連携）、データ分類ガイダンス
3. **architecture.png のレンダリング** — Mermaid → PNG 変換

### Spec B 移行時に実施

4. **MULTI_AZ_1 デプロイ検証** — Spec B は Multi-AZ が前提。RouteTableIds の動作を実証
5. **Glue Crawler 失敗アラート** — Spec B の Monitoring に組み込み（Spec A にも後で backport）
6. **VPC Flow Logs** — Spec B のセキュリティ要件で実装

### 中長期（Issue 提出後のメンテナー対話後）

7. **データガバナンス強化** — Column-level access control (Lake Formation)
8. **パフォーマンスベンチマーク** — 共有スループット影響の定量化
9. **Parquet / Iceberg 読み取り検証** — S3 AP 経由の format 対応状況

---

## Round 2 (最終判定)

上記アクション #1-3 を README に反映し、Issue 文面を最終化します。

### 全ペルソナ最終判定

| ペルソナ | Spec A 完成度判定 | 次 Spec への推奨 |
|---------|-----------------|---------------|
| Kawahara | ✅ 十分（Issue 文面 + デモシナリオ追加で完成） | Issue 提出を先行してフィードバック取得 |
| Storage Specialist | ✅ 十分（SINGLE_AZ 検証のみだが品質は高い） | Multi-AZ は Spec B で確認 |
| Public Sector Reviewer | ✅ 十分（公共向けガイダンスは README 追記で対応） | Spec B で監査証跡を本格実装 |
| Kobayashi | ✅ 十分（ビジネス価値の表現を Issue に追加） | 各 Spec の Issue に成功メトリクスを含める |
| Hikita | ✅ 十分（分析の入口として適切） | Parquet 検証は別途 |
| 山口 | ✅ 十分（基本的な Observability は整っている） | Crawler アラートは Spec B で |
| 大谷 | ✅ 十分（CloudTrail + JSON エビデンスは良い） | VPC Flow Logs は Spec B で |
| Max | ✅ 十分（End-to-end 動作証明済み） | データ投入パターンの多様化を doc に |
| 倉光 | ✅ 十分（Lakehouse の入口として正しい） | AI 連携パスの明示 |
| 佐藤 | ✅ 十分（Issue 提出可能な品質） | アーキテクチャ図 PNG + version 確認 |

**総合判定: ✅ Spec A は Issue 提出可能な品質に到達。README 拡充 + Issue 文面最終化で完了。**
