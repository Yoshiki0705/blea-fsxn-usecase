# BLEA FSx for ONTAP ユースケース

> BLEA (Baseline Environment on AWS) ゲストシステムユースケース: Amazon FSx for NetApp ONTAP によるエンタープライズファイルストレージ

## 概要

このリポジトリは、[Baseline Environment on AWS (BLEA)](https://github.com/aws-samples/baseline-environment-on-aws) への貢献を目的とした CDK ユースケーステンプレートを開発しています。Amazon FSx for NetApp ONTAP を活用した 4 つのユースケースを提供します。

## ユースケース一覧

| Spec | ディレクトリ | 説明 | ターゲット |
|------|------------|------|----------|
| A | `blea-guest-fsxn-data-analytics-sample` | NFS → S3 AP → Glue/Athena 分析 | BLEA 本体 |
| B | `guest-fsxn-cyber-resilience-sample` | TPS + ARP + SnapLock + Air-gapped Vault | BLEA for FSI |
| G | `blea-guest-fsxn-flexcache-sample` | FlexCache 分散拠点アクセス高速化 | BLEA 本体 |
| H | `blea-guest-fsxn-modernization-sample` | 5 コンピュートパターン共有ストレージ | BLEA 本体 |

## Spec A: データ分析 (PR #1304 提出済み)

FSx for ONTAP + S3 Access Point + Glue Crawler + Athena SQL 分析パターン。

```
FSx for ONTAP (NFS) → S3 Access Point → Glue Crawler → Athena SQL
```

## Spec B: サイバーレジリエンス (FISC 準拠)

多層防御によるランサムウェア対策。マルチアカウントアーキテクチャ。

```
TPS (管理者削除不可) + ARP/AI (自動検知) + SnapLock (WORM)
+ Air-gapped Vault (別アカウント) + 自動ネットワーク隔離
```

## Spec G: FlexCache 分散拠点

本庁 (Origin) と支所 (Cache) 間のファイルアクセス高速化。

```
Origin FSx for ONTAP ←VPC Peering→ Cache FSx for ONTAP (FlexCache)
  本庁ユーザー                支所ユーザー (ローカルSSD性能)
```

## Spec H: モダナイゼーションプラットフォーム

VMware/オンプレミスからの移行時の共有ストレージ基盤。5 コンピュートパターン対応。

```
FSx for ONTAP (共有ストレージ)
├── EC2 ASG (NFS mount)
├── ECS Fargate (S3 AP)
├── EKS (Trident CSI)
├── Lambda (S3 AP)
└── AWS Batch (NFS + Spot)
```

## 開発

```bash
# 依存パッケージのインストール
npm ci

# 全 Spec ビルド
npm run build

# 全 Spec テスト
npm test

# 個別 Spec の CDK Synth
cd usecases/blea-guest-fsxn-data-analytics-sample
npx cdk synth
```

## ステータス

| Spec | 実装 | テスト | デプロイ検証 | PR |
|------|------|--------|------------|-----|
| A | ✅ | 14 pass | ✅ E2E 完了 | PR #1304 |
| B | ✅ | 13 pass | ✅ 49 リソース | — |
| G | ✅ | 12 pass | 予算依存 | — |
| H | ✅ | 10 pass | ✅ 41 リソース | — |

## 共有モジュール

`shared/` ディレクトリに全 Spec で再利用するリソースを配置：

- `shared/lambda/ontap-custom-resource/` — ONTAP REST API クライアント
- `shared/templates/` — tsconfig, jest.config, cdk.json テンプレート
- `shared/docs/` — デプロイ検証テンプレート

## 貢献先

- **BLEA 本体**: `aws-samples/baseline-environment-on-aws` (Spec A, G, H)
- **BLEA for FSI**: `aws-samples/baseline-environment-on-aws-for-financial-services-institute` (Spec B)

## ライセンス

MIT-0
