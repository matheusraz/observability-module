locals {
  buckets = [var.mimir.blocks_bucket_name, var.mimir.alertmanager_bucket_name, var.mimir.ruler_bucket_name]
}

resource "aws_iam_policy" "mimir_policy" {
  count       = var.mimir.setup == true ? 1 : 0
  name        = "mimir-policy"
  path        = "/"
  description = "Policy to grant access to Mimir"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "MimirStorage",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.mimir.blocks_bucket_name}",
          "arn:aws:s3:::${var.mimir.blocks_bucket_name}/*",
          "arn:aws:s3:::${var.mimir.alertmanager_bucket_name}",
          "arn:aws:s3:::${var.mimir.alertmanager_bucket_name}/*",
          "arn:aws:s3:::${var.mimir.ruler_bucket_name}",
          "arn:aws:s3:::${var.mimir.ruler_bucket_name}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket.mimir]
}

resource "aws_iam_role_policy_attachment" "mimir_policy" {
  count      = var.mimir.setup == true ? 1 : 0
  policy_arn = aws_iam_policy.mimir_policy[count.index].arn
  role       = aws_iam_role.mimir_role[count.index].name
}

resource "aws_iam_role" "mimir_role" {
  count = var.mimir.setup == true ? 1 : 0
  name  = "herewith-mimir-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${var.account_id}:oidc-provider/oidc.eks.${var.aws_region}.amazonaws.com/id/${element(split("/", var.cluster_oidc_issuer), length(split("/", var.cluster_oidc_issuer)) - 1)}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "oidc.eks.${var.aws_region}.amazonaws.com/id/${element(split("/", var.cluster_oidc_issuer), length(split("/", var.cluster_oidc_issuer)) - 1)}:sub" : "system:serviceaccount:observability:herewith-mimir"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "mimir" {
  count  = var.mimir.setup == true ? 3 : 0
  bucket = local.buckets[count.index]
}

resource "helm_release" "mimir" {
  count            = var.mimir.setup == true ? 1 : 0
  repository       = "https://grafana.github.io/helm-charts"
  name             = "herewith-mimir"
  chart            = "mimir-distributed"
  namespace        = "observability"
  create_namespace = true
  values = [<<EOF
serviceAccount:
  name: herewith-mimir
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.mimir_role[count.index].arn}
gateway:
  enabledNonEnterprise: true
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      nginx.ingress.kubernetes.io/whitelist-source-range: 18.158.152.131/32, 52.26.13.5/32
    hosts:
    - host: ${var.mimir.ingress_domain}
      paths:
        - path: /
          pathType: Prefix
    tls: {}
minio:
  enabled: false
nginx:
  enabled: false
compactor:
  persistentVolume:
    size: 50Gi
ingester:
  persistentVolume:
    size: 50Gi
  replicas: 2
  zoneAwareReplication:
    enabled: false
store_gateway:
  persistentVolume:
    size: 50Gi
  zoneAwareReplication:
    enabled: false
runtimeConfig:
  overrides:
    herewith-production:
      max_label_names_per_series: 40
    herewith-staging:
      max_label_names_per_series: 40
mimir:
  structuredConfig:
    limits:
      max_global_series_per_user: 1000000
    common:
      storage:
        backend: s3
        s3:
          endpoint: s3.${var.aws_region}.amazonaws.com
          region: ${var.aws_region}
          secret_access_key: null
          access_key_id: null

    blocks_storage:
      s3:
        bucket_name: ${var.mimir.blocks_bucket_name}
    alertmanager_storage:
      s3:
        bucket_name: ${var.mimir.alertmanager_bucket_name}
    ruler_storage:
      s3:
        bucket_name: ${var.mimir.ruler_bucket_name}
  EOF
  ]

  depends_on = [aws_s3_bucket.mimir]
}