# 全 Spec 実装完了レビュー: Named ペルソナアドバイス

> 日付: 2026-06-04
> 対象: 全 4 Spec の実装済みコード + 全ペルソナ

## 実装サマリー

| Spec | Resources | Tests | Key Components |
|------|-----------|-------|----------------|
| A: Data Analytics | 34 | 14 | FSx for ONTAP + S3 AP + Glue + Athena + LF permissions |
| B: Cyber Resilience | 63 (3 stacks) | 13 | TPS + ARP + SnapLock + Backup + Isolation |
| G: FlexCache | 45 | 12 | 2 FSx for ONTAP + VPC Peering + FlexCache CR |
| H: Modernization | 37 | 10 | FSx for ONTAP + S3 AP + EC2 (NFS) + Lambda (S3 AP) |
| **Total** | **179** | **49** | |

---

## ペルソナ別アドバイス

### Kawahara-san (Partner/SI)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| 全体 | **ユースケース選択ガイド**が欠落。パートナーが「この顧客にはどの Spec を提案すべきか」を判断するデシジョンツリーが必要 | `doc/` にユースケース選択ガイドを作成 |
| 全体 | **クイック PoC 手順**: 各 Spec で「30分で動くデモ」の手順があると Partner/SI が提案しやすい | 各 README にクイック手順追加（Spec A は追加済み） |
| B | 3 アカウント構成は SI 提案時の**オーバーヘッドが高い**。まず単一アカウントでの TPS+ARP のみのシンプル版が欲しい | 将来: minimal variant (single-account) を検討 |

### Storage Specialist

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| G | **FlexCache TTL のドキュメント**: 1 時間のデフォルト stale read がユーザーに影響するケースの説明が README に必要 | doc/README_ja.md 作成時に含める |
| H | **EC2 NFS mount オプション**が適切 (`noresvport,hard,rsize=262144`)。ただし `vers=4.1` の明示がないため NFSv3 にフォールバックする可能性あり。`-o nfsvers=4.1` を追加推奨 | compute-ec2.ts の UserData を修正 |
| 全体 | **volume auto-size** が未実装。FSx for ONTAP は `autosize` 設定があり、volume が満杯になる前に自動拡張できる。parameter.ts で auto-size を有効にすべき | 将来改善 (ONTAP CLI 設定 or CloudFormation 対応待ち) |

### Public Sector / Governance Reviewer

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| B | **DR 訓練の頻度**: 実装では月次 EventBridge を設計したが、StepFunctions はまだ placeholder。年 1 回以上の実施を FISC は推奨。ドキュメントに明記 | README に記載 |
| G | **FlexCache のデータ主権**: キャッシュ側のデータは origin の「複製」であり、キャッシュ側での「正データ」としての法的位置付けがない。公共セクターではこの区別が重要 | README に注記追加 |

### Kobayashi-san (Outcome / Business Value)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| 全体 | **ビジネス KPI**: 各 Spec で「導入前/後の具体的改善指標」が不明。例: A=「データ活用率 0%→分析可能」、B=「RPO 24h→1h」、G=「支所アクセス遅延 200ms→5ms」 | 各 README に「期待される効果」セクション追加 |
| 全体 | **コスト対効果**: 既存方式との比較表が欲しい。「S3 コピー + ETL vs FSx for ONTAP S3 AP」「テープバックアップ vs TPS + Air-gapped」 | 各 README に追加 |

### Hikita-san (Analytics / Iceberg)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| A | Glue Crawler → Athena はフルスキャンになる。**パーティション設計**（year/month 等）のガイダンスが README に不足。大規模データでは致命的なコスト増 | README に「スケールアップ時の推奨」セクション追加 |
| A | **Parquet 対応の検証結果**が共有されていない。CSV は動作確認済みだが、Parquet (カラムナ形式) の S3 AP 経由読み取りテストが未実施 | 将来の検証タスクとして記録 |

### 山口 (Observability / SRE)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| G | **FlexCache metrics**: カスタムメトリクス Lambda が未実装 (Task 3 pending)。これがないと cache hit ratio アラームが動作しない。**次に優先実装すべき** | 優先: Task 3 実装 |
| H | **CapacityManager Lambda**: 設計はあるが未実装 (Task 9)。auto-remediation がないとアラームの意味が半減。**次に優先** | 優先: Task 9 実装 |
| 全体 | **SLO 共通化**: Spec A に SLI/SLO を定義したが B/G/H には含まれていない。共通の SLO テンプレートが必要 | shared/docs に SLO テンプレート追加 |

### 大谷 (Log Analytics / SIEM)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| B | **ログ保持の実装**: 設計 (3年保持) はあるが CDK でログ保持期間を設定しているのは Lambda のみ。CloudTrail → S3 (長期保管) の設定が CDK に含まれていない | 将来タスク: CloudTrail → S3 export construct |
| G | FlexCache のアクセスログは ONTAP audit log でしか取れない。**CDK スコープ外**だが、ドキュメントで「ONTAP CLI で audit log を有効化する手順」を記載すべき | README に追記 |

### Max (IoT / ONTAP)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| H | EC2 pattern は IoT ゲートウェイからの NFS 書き込みに使える。Lambda pattern は S3 AP 経由のイベント駆動処理に使える。**IoT データパイプラインとしての活用例**を README に含めると横展開しやすい | README に言及追加 |
| G | FlexCache + 工場拠点のパターンは**エッジ → クラウドのデータ同期**として有用。拠点の回線品質が悪い場合の挙動 (disconnected mode) をドキュメント化すべき | README に追記 |

### 倉光 (Data + AI / Lakehouse)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| A | Glue Data Catalog で登録されたテーブルを**SageMaker / Bedrock KB から直接参照できるか**の接続パスが README にない。analytics → AI の連続パスを示すべき | README「次のステップ」に含まれているが、より具体的なコード例を追加 |
| 全体 | データガバナンス: **Lake Formation の column-level access control** まで踏み込めると金融・公共向けに強い。現状は ALL 権限で付与しており粒度が粗い | 将来改善 (Phase 2) |

### 佐藤真也 (FSI + ONTAP SA)

| Spec | アドバイス | 対応方針 |
|------|----------|---------|
| H | **NFSv4.1 の明示**: `vers=4.1` オプション未指定。FSx for ONTAP は NFSv3/v4.0/v4.1 をサポートするが、性能・セキュリティ面で v4.1 推奨 | compute-ec2.ts 修正 |
| B | SnapVault (Task 7) は SnapMirror `type: vault` で実装するが、ONTAP 9.17.1 の REST API パスが `/api/snapmirror/relationships` であることを事前に確認すべき。ドキュメント版とバージョンで差異がある可能性 | Task 7 実装前に API ドキュメント確認 |
| G | **同一リージョン内 FlexCache**: VPC Peering で動作する設計は正しい。ただし cross-region の場合は Transit Gateway 必須であることを README に明記 | README に追記 |

---

## 即座に改善する項目 (P1)

| # | 対応 | Spec | 所要時間 |
|---|------|------|---------|
| 1 | EC2 NFS mount に `nfsvers=4.1` 追加 | H | 1分 |
| 2 | ユースケース選択ガイド (doc/usecase-selection-guide.md) | 全体 | 15分 |

### 改善 #1: NFSv4.1 明示


## 改善実施結果

| # | 改善 | 実施 | 検証 |
|---|------|------|------|
| 1 | EC2 NFS mount に `nfsvers=4.1` 追加 | ✅ compute-ec2.ts 修正 | ✅ 10 tests pass |
| 2 | ユースケース選択ガイド作成 | ✅ doc/usecase-selection-guide.md | - |

---

## 全ペルソナ最終判定 (Round 2)

| ペルソナ | 判定 | 残タスクへの推奨 |
|---------|------|---------------|
| Kawahara (Partner/SI) | ✅ | 選択ガイド作成済み。各 Spec README にクイック手順を追加 |
| Storage Specialist | ✅ | NFSv4.1 修正済み。volume auto-size は将来改善 |
| Public Sector Reviewer | ✅ | DR 訓練頻度・データ主権は README 作成時に含める |
| Kobayashi (Outcome) | ✅ | 期待効果を選択ガイドに含めた。各 README にも追加推奨 |
| Hikita (Analytics) | ✅ | パーティション設計・Parquet は README 拡充時に対応 |
| 山口 (Observability) | ⚠️ | **FlexCache metrics Lambda (G-Task3) + CapacityManager (H-Task9) が次の優先** |
| 大谷 (Log/SIEM) | ✅ | CloudTrail S3 export は将来構築。ドキュメントで手順記載 |
| Max (IoT) | ✅ | IoT パイプライン活用例は README に追記推奨 |
| 倉光 (Data+AI) | ✅ | AI 連携パスの具体化は README 拡充時に |
| 佐藤 (FSI+ONTAP) | ✅ | NFSv4.1 修正済み。SnapMirror API パス確認は Task 7 前に |

---

## 次のアクション優先順位

1. **Spec G: Task 3** — FlexCache Metrics Collection Lambda（山口レビュー: ないとアラーム動作しない）
2. **Spec H: Task 9** — CapacityManager Lambda（山口レビュー: auto-remediation）
3. **Spec B: Task 7** — SnapVault API 検証 + 実装
4. **全体: ドキュメント** — 各 Spec の README 完成（TTL, 期待効果, パーティション）
5. **Spec B/G/H: デプロイ検証** — 実環境テスト
6. **Spec B: BLEA for FSI Issue/PR** — 提出準備
