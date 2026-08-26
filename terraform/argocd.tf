resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  wait = false 
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  depends_on = [
    aws_eks_cluster.project_eks
  ]
}

resource "kubectl_manifest" "argocd_application" {
  depends_on = [
    helm_release.argocd
  ]

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "online-boutique"
      namespace = "argocd"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/Siddhesh-07/eks-project.git"
        targetRevision = "main"
        path           = "kubernetes-manifests"

        kustomize = {}
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }

        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })
}