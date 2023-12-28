# resource "helm_release" "otel_collector" {
#   repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
#   name             = "herewith-otel"
#   chart            = "opentelemetry-collector"
#   namespace        = "observability"
#   create_namespace = true
#   values = [<<EOF
#         mode: daemonset
#         service:
#             enabled: true
#         config:
#             processors:
#                 resource:
#                     attributes:
#                     - action: insert
#                       key: loki.resource.labels
#                       value: app_name, container, cronjob
#                     - action: insert
#                       key: app_name
#                       from_attribute: k8s.deployment.name
#                     - action: insert
#                       key: container
#                       from_attribute: k8s.container.name
#                     - action: insert
#                       key: cronjob
#                       from_attribute: k8s.cronjob.name
#                     - action: insert
#                       key: loki.format
#                       value: logfmt

#             exporters:
#                 logging:
#                     loglevel: debug
#                 loki:
#                     endpoint: "http://loki-write:3100/loki/api/v1/push"
#                     headers:
#                         "X-Scope-OrgID": herewith
#                 otlphttp:
#                     endpoint: http://herewith-tempo-distributor:4318
#                     headers:
#                       x-scope-orgid: herewith
#                     tls:
#                         insecure: true
#             service:
#                 pipelines:
#                     logs:
#                         exporters: [loki, logging]
#                         processors: [resource]
#                         receivers: [filelog]
#                     traces:
#                         exporters: [otlphttp]
#         presets:
#             logsCollection:
#                 enabled: true
#                 includeCollectorLogs: false
#             kubernetesAttributes:
#                 enabled: true
#     EOF
#   ]

#   depends_on = [helm_release.loki, helm_release.tempo]
# }

# resource "helm_release" "otel_demo" {
#   repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
#   name             = "herewith-otel-demo"
#   chart            = "opentelemetry-demo"
#   namespace        = "apps"
#   create_namespace = true
#   values = [<<EOF
# default:
#   envOverrides:
#     - name: OTEL_COLLECTOR_NAME
#       value: herewith-otel-opentelemetry-collector.observability

# opentelemetry-collector:
#   enabled: false

# jaeger:
#   enabled: false

# prometheus:
#   enabled: false

# grafana:
#   enabled: false
#   EOF
#   ]

#   depends_on = [helm_release.otel_collector]
# }