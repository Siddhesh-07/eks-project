resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  values = [
    yamlencode({
      grafana = {
        enabled = true

        service = {
          type = "ClusterIP"
        }

        persistence = {
          enabled = false
        }

        defaultDashboardsEnabled = true
      }

      prometheus = {
        enabled = true

        prometheusSpec = {
          retention = "7d"

          resources = {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }

      alertmanager = {
        enabled = true
      }

      nodeExporter = {
        enabled = true
      }

      kubeStateMetrics = {
        enabled = true
      }
    })
  ]

  depends_on = [
    aws_eks_cluster.project_eks
  ]
}