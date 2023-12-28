resource "aws_iam_policy" "tempo_policy" {
  count       = var.tempo.setup == true ? 1 : 0
  name        = "tempo-policy"
  path        = "/"
  description = "Policy to grant access to tempo"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "TempoPermissions",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ],
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.tempo[count.index].id}",
          "arn:aws:s3:::${aws_s3_bucket.tempo[count.index].id}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket.tempo]
}

resource "aws_iam_role_policy_attachment" "tempo_policy" {
  count      = var.tempo.setup == true ? 1 : 0
  policy_arn = aws_iam_policy.tempo_policy[count.index].arn
  role       = aws_iam_role.tempo_role[count.index].name
}

resource "aws_iam_role" "tempo_role" {
  count = var.tempo.setup == true ? 1 : 0
  name  = "herewith-tempo-role"

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
            "oidc.eks.${var.aws_region}.amazonaws.com/id/${element(split("/", var.cluster_oidc_issuer), length(split("/", var.cluster_oidc_issuer)) - 1)}:sub" : "system:serviceaccount:observability:herewith-tempo"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "tempo" {
  count  = var.tempo.setup == true ? 1 : 0
  bucket = var.tempo.bucket_name
}

resource "helm_release" "tempo" {
  count            = var.tempo.setup == true ? 1 : 0
  repository       = "https://grafana.github.io/helm-charts"
  name             = "herewith-tempo"
  chart            = "tempo-distributed"
  namespace        = "observability"
  create_namespace = true
  values = [<<EOF
serviceAccount:
  name: herewith-tempo
  annotations:
    "eks.amazonaws.com/role-arn": ${aws_iam_role.tempo_role[count.index].arn}
metricsGenerator:
  enabled: true
  config:
    storage:
      remote_write:
      - name: herewith
        url: http://prom-stack-kube-prometheus-prometheus:9090/api/v1/write
        send_exemplars: true
gateway:
  enabled: false
queryFrontend:
  query:
    enabled: false
  replicas: 1
tempo:
  storage:
    trace:
      backend: s3
      s3:
        bucket: ${var.tempo.bucket_name}
        endpoint: s3.dualstack.${var.aws_region}.amazonaws.com
        region: ${var.aws_region}
        insecure: true
multitenancyEnabled: true
overrides: |
  overrides:
    "herewith-production":
      block_retention: 7d
      ingestion_burst_size_bytes: 20000000
      ingestion_rate_limit_bytes: 15000000
      metrics_generator_processors:
        - service-graphs
        - span-metrics
    "herewith-staging":
      block_retention: 7d
      ingestion_burst_size_bytes: 20000000
      ingestion_rate_limit_bytes: 15000000
      metrics_generator_processors:
        - service-graphs
        - span-metrics
traces:
  otlp:
    grpc:
      enabled: true
    http:
      enabled: true
  zipkin:
    enabled: false
  jaeger:
    thriftHttp:
      enabled: false
  opencensus:
    enabled: false
    EOF
  ]
}