resource "helm_release" "grafana" {
  count = var.grafana.setup == true ? 1 : 0

  repository       = "https://grafana.github.io/helm-charts"
  name             = "herewith-grafana"
  chart            = "grafana"
  namespace        = "observability"
  create_namespace = true
  values = [<<EOF
  # extraConfigmapMounts:
  # - name: grafana-dashboards
  #   mountPath: /etc/dashboards
  #   configMap: grafana-dashboards
  #   readOnly: true
  # extraContainerVolumes:
  # - configMap:
  #     defaultMode: 420
  #     name: grafana-dashboards
  #   name: grafana-dashboards
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
    - grafana.platform.quoori.eu
  persistence:
    enabled: true
  # grafana.ini:
  #   server:
  #     root_url: https://grafana.platform.quoori.eu/
  #   auth.google:
  #     oauth_allow_insecure_email_lookup: true
  #     cookie_samesite: lax
  #     enabled: true
  #     allow_sign_up: true
  #     auto_login: true
  #     client_id: 430373429524-chtk94m27pk0gegtbvqdnkle34et6b47.apps.googleusercontent.com
  #     client_secret: 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
  #     scopes: https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email
  #     auth_url: https://accounts.google.com/o/oauth2/auth
  #     token_url: https://oauth2.googleapis.com/token
  #     api_url: https://openidconnect.googleapis.com/v1/userinfo
  #     allowed_domains: herewith.com
  #     hosted_domain: herewith.com
  #     use_pkce: true
  #     skip_org_role_sync: true
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: default
        type: file
        disableDeletion: false
        editable: false
        options:
          path: /var/lib/grafana/dashboards/default
  dashboardsConfigMaps:
    default: grafana-dashboards
  # dashboards:
  datasources:
    datasources.yaml:
      apiVersion: 1
      deleteDatasources:
      - name: Logs Staging
      - name: Logs Production
      - name: Metrics Staging
      - name: Metrics Production
      datasources:
      - name: Logs Staging
        type: loki
        access: proxy
        url: "http://loki-gateway.observability"
        jsonData:
          httpHeaderName1: 'X-Scope-OrgID'
        secureJsonData:
          httpHeaderValue1: 'herewith-staging'
      - name: Logs Production
        type: loki
        access: proxy
        url: "http://loki-gateway.observability"
        jsonData:
          httpHeaderName1: 'X-Scope-OrgID'
        secureJsonData:
          httpHeaderValue1: 'herewith-production'
      - name: Metrics Staging
        type: prometheus
        typeName: Prometheus
        typeLogoUrl: https://grafana.com/static/img/logos/logo-mimir.svg
        access: proxy
        url: http://herewith-mimir-gateway.observability/prometheus
        user: ""
        database: ""
        basicAuth: false
        isDefault: false
        jsonData:
          httpHeaderName1: X-Scope-OrgID
          httpMethod: POST
          prometheusType: Mimir
          prometheusVersion: 2.9.0
        secureJsonData:
          httpHeaderValue1: 'herewith-staging'
        readOnly: true
      - name: Metrics Production
        type: prometheus
        typeName: Prometheus
        typeLogoUrl: https://grafana.com/static/img/logos/logo-mimir.svg
        access: proxy
        url: http://herewith-mimir-gateway.observability/prometheus
        user: ""
        database: ""
        basicAuth: false
        isDefault: false
        jsonData:
          httpHeaderName1: X-Scope-OrgID
          httpMethod: POST
          prometheusType: Mimir
          prometheusVersion: 2.9.0
        secureJsonData:
          httpHeaderValue1: 'herewith-production'
        readOnly: true
  EOF
  ]

  depends_on = [helm_release.loki, helm_release.mimir, kubectl_manifest.dashboards]
}

resource "kubectl_manifest" "dashboards" {
  count = var.grafana.setup == true ? 1 : 0

  yaml_body         = file("${path.module}/grafana-dashboards/grafana-dashboards.yaml")
  server_side_apply = true
}
