resource "aws_iam_policy" "loki_policy" {
  count       = var.loki.setup == true ? 1 : 0
  name        = "loki-policy"
  path        = "/"
  description = "Policy to grant access to Loki"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "LokiStorage",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.loki_chunks[count.index].id}",
          "arn:aws:s3:::${aws_s3_bucket.loki_chunks[count.index].id}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket.loki_chunks]
}

resource "aws_iam_role_policy_attachment" "loki_policy" {
  count      = var.loki.setup == true ? 1 : 0
  policy_arn = aws_iam_policy.loki_policy[count.index].arn
  role       = aws_iam_role.loki_role[count.index].name
}

resource "aws_iam_role" "loki_role" {
  count = var.loki.setup == true ? 1 : 0
  name  = "herewith-loki-role"

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
            "oidc.eks.${var.aws_region}.amazonaws.com/id/${element(split("/", var.cluster_oidc_issuer), length(split("/", var.cluster_oidc_issuer)) - 1)}:sub" : "system:serviceaccount:observability:herewith-loki"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "loki_chunks" {
  count  = var.loki.setup == true ? 1 : 0
  bucket = var.loki.bucket_name
}

resource "helm_release" "loki" {
  count            = var.loki.setup == true ? 1 : 0
  repository       = "https://grafana.github.io/helm-charts"
  name             = "herewith-logs"
  chart            = "loki"
  namespace        = "observability"
  create_namespace = true
  values = [<<EOF
    gateway:
      ingress:
        enabled: true
        annotations:
          kubernetes.io/ingress.class: nginx
          nginx.ingress.kubernetes.io/whitelist-source-range: 18.158.152.131/32, 52.26.13.5/32
        hosts:
        - host: ${var.loki.ingress_domain}
          paths:
            - path: /
              pathType: Prefix
        tls: {}
    write:
      replicas: 2
    read:
      replicas: 2
    backend:
      replicas: 2
    serviceAccount:
        name: herewith-loki
        annotations:
          "eks.amazonaws.com/role-arn": ${aws_iam_role.loki_role[count.index].arn}
    loki:
      rulerConfig:
        alertmanager_url: http://herewith-mimir-alertmanager:8080/alertmanager
        enable_api: true
      limits_config:
        max_query_series: 100000
        max_query_parallelism: 2
      storage:
        bucketNames:
          chunks: ${aws_s3_bucket.loki_chunks[count.index].id}
          ruler: ${aws_s3_bucket.loki_chunks[count.index].id}
          admin: ${aws_s3_bucket.loki_chunks[count.index].id}
        type: s3
        s3:
          s3: s3://${var.aws_region}/${aws_s3_bucket.loki_chunks[count.index].id}
          secretAccessKey: null
          accessKeyId: null
          s3forcepathstyle: false
          region: ${var.aws_region}
          insecure: false
          sse_encryption: false
      tableManager:
        enabled: true
        retention_deletes_enabled: true
        retention_period: 336h
  EOF
  ]

  depends_on = [aws_s3_bucket.loki_chunks]
}