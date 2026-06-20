# Shared Modules

共通モジュール: 全 Spec (A, B, G, H) で再利用される CDK Construct、Lambda、スクリプト、テンプレート。

## 構成

```
shared/
├── constructs/
│   ├── fsxn-base/           # FSx for ONTAP FileSystem + SVM + Volume の共通 Construct
│   ├── networking-base/     # VPC + Private Subnets + Endpoints の共通 Construct
│   ├── monitoring-base/     # SNS + Chatbot + Alarm パターン
│   └── s3-access-point/     # CfnS3AccessPointAttachment ラッパー
├── lambda/
│   └── ontap-custom-resource/  # ONTAP REST API Custom Resource (Spec B, G, H 用)
├── scripts/
│   ├── cleanup-fsxn-stack.sh   # RETAIN リソース対応のスタック削除自動化
│   ├── verify-stack.sh         # デプロイ後のリソース検証レポート
│   ├── deploy-and-verify.sh    # デプロイ＋検証自動化テンプレート
│   ├── generate-test-data.py   # テストデータ生成
│   └── collect-evidence.sh     # エビデンス収集
├── templates/
│   ├── parameter-base.ts       # AppParameter 基本インターフェース
│   ├── jest.config.js          # Jest 設定テンプレート
│   ├── tsconfig.json           # TypeScript 設定テンプレート
│   └── cdk.json                # CDK 設定テンプレート
└── docs/
    ├── deployment-verification-template.md  # 検証チェックリストテンプレート
    └── cost-estimate-template.md            # コスト見積もりテンプレート
```

## 利用方法

各ユースケースは `shared/` のモジュールをコピーまたはシンボリックリンクで利用:
- CDK Construct: 直接 import（npm workspace で共有）
- Scripts: コピーして usecase 固有のパラメータを設定
- Templates: コピーしてカスタマイズ

## Spec 別の利用マトリクス

| 共通モジュール | Spec A | Spec B | Spec G | Spec H |
|-------------|--------|--------|--------|--------|
| fsxn-base | ✅ | ✅ | ✅ (×2: origin+cache) | ✅ |
| networking-base | ✅ | ✅ | ✅ (×2) | ✅ |
| monitoring-base | ✅ | ✅ | ✅ | ✅ |
| s3-access-point | ✅ | - | ✅ (optional) | ✅ |
| ontap-custom-resource | - | ✅ (TPS+ARP) | ✅ (FlexCache) | ✅ (FlexClone+TPS) |
| deploy-and-verify.sh | ✅ | ✅ | ✅ | ✅ |
| generate-test-data.py | ✅ | ✅ | ✅ | ✅ |
| deployment-verification-template.md | ✅ | ✅ | ✅ | ✅ |
