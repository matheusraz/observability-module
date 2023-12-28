resource "kubectl_manifest" "kuma_app" {
  count       = var.kuma.setup == true ? 1 : 0

  yaml_body = <<YAML
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      app: uptime-kuma
    name: uptime-kuma
    namespace: observability
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: uptime-kuma
    template:
      metadata:
        labels:
          app: uptime-kuma
      spec:
        containers:
        - image: louislam/uptime-kuma:1
          name: uptime-kuma
          volumeMounts:
          - name: storage
            mountPath: /app/data
        volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: uptime-kuma
  YAML
}

resource "kubectl_manifest" "kuma_svc" {
  count       = var.kuma.setup == true ? 1 : 0

  yaml_body = <<YAML
  apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: uptime-kuma
    name: uptime-kuma
    namespace: observability
  spec:
    ports:
    - port: 80
      protocol: TCP
      targetPort: 3001
    selector:
      app: uptime-kuma
  YAML
}

resource "kubectl_manifest" "kuma_ingress" {
  count       = var.kuma.setup == true ? 1 : 0

  yaml_body = <<YAML
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    annotations:
      kubernetes.io/ingress.class: nginx
    labels:
      app: uptime-kuma
    name: uptime-kuma
    namespace: observability
  spec:
    rules:
    - host: uptime.platform.quoori.eu
      http:
        paths:
        - backend:
            service:
              name: uptime-kuma
              port:
                number: 80
          path: /
          pathType: Prefix
  YAML
}

resource "kubectl_manifest" "kuma_pvc" {
  count       = var.kuma.setup == true ? 1 : 0

  yaml_body = <<YAML
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    labels:
      app: uptime-kuma
    name: uptime-kuma
    namespace: observability
  spec:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
    storageClassName: gp2
  YAML
}

// Kuma Admin password

resource "random_password" "password" {
  count       = var.kuma.setup == true ? 1 : 0

  length           = 22
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "kuma" {
  count       = var.kuma.setup == true ? 1 : 0

  name = "kuma-admin-password"
}

resource "aws_secretsmanager_secret_version" "kuma" {
  count       = var.kuma.setup == true ? 1 : 0
  
  secret_id     = aws_secretsmanager_secret.kuma.id
  secret_string = random_password.password.result
}