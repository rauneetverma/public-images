# Create a shorter release name by using instance name and truncated environment
# Kubernetes label limit is 63 characters, Helm adds suffixes, so keep under 40 chars
locals {
  # Use first 20 chars of environment name to keep release name short
  env_short    = substr(var.environment.unique_name, 0, 20)
  release_name = "${var.instance_name}-${local.env_short}"

  # Extract spec with defaults using lookup
  spec = lookup(var.instance, "spec", {})

  # Extract values with defaults
  registry_domain          = lookup(local.spec, "registry_domain", "")
  admin_password           = lookup(local.spec, "admin_password", "")
  admin_username           = lookup(local.spec, "admin_username", "admin")
  storage_size             = lookup(local.spec, "postgres_storage_size", "50Gi")
  expose_type              = lookup(local.spec, "expose_type", "ingress")
  ingress_class_name       = lookup(local.spec, "ingress_class_name", null)
  namespace                = lookup(local.spec, "namespace", "harbor")
  chart_version            = lookup(local.spec, "chart_version", "1.14.0")
  enable_https             = lookup(local.spec, "enable_https", true)
  enable_trivy             = lookup(local.spec, "enable_trivy", true)
  database_type            = lookup(local.spec, "database_type", "internal")
  redis_type               = lookup(local.spec, "redis_type", "internal")
  replicas                 = lookup(local.spec, "core_replicas", 1)
  redis_persistence        = lookup(local.spec, "redis_persistence", false)
  postgresql_persistence   = lookup(local.spec, "postgresql_persistence", false)
  postgresql_storage_class = lookup(local.spec, "postgresql_storage_class", null)

  # User-supplied Helm values - allows users to override or extend default configuration
  advanced                  = lookup(var.instance, "advanced", {})
  user_supplied_helm_values = lookup(local.advanced, "values", {})
}

resource "helm_release" "harbor" {
  name = local.release_name
  # repository       = "${path.module}/harbor"
  # repository       = "https://helm.goharbor.io"
  chart = "${path.module}/harbor"
  # version is not used for local charts - it uses Chart.yaml version
  namespace        = local.namespace
  create_namespace = true
  timeout          = 600
  wait             = true
  replace          = true
  force_update     = true

  values = [
    yamlencode({
      # Exposure configuration - Official Harbor chart structure
      expose = merge(
        {
          type = local.expose_type
          tls = {
            enabled = local.enable_https
          }
          ingress = {
            hosts = {
              core = local.registry_domain
            }
          }
        },
        # Only set ingressClassName if it's explicitly provided
        local.ingress_class_name != null ? {
          ingress = {
            className = local.ingress_class_name
            hosts = {
              core = local.registry_domain
            }
          }
        } : {}
      )

      externalURL = local.enable_https ? "https://${local.registry_domain}" : "http://${local.registry_domain}"

      # Admin credentials
      harborAdminPassword = local.admin_password

      # PostgreSQL database configuration (Official Harbor chart)
      database = {
        type = local.database_type
        internal = {
          enabled = local.database_type == "internal" ? true : false
          resources = {
            requests = {
              memory = lookup(local.spec, "postgres_memory", "512Mi")
              cpu    = lookup(local.spec, "postgres_cpu", "200m")
            }
          }
          persistence = merge(
            {
              enabled = local.postgresql_persistence
              size    = local.storage_size
            },
            # Only set storageClass if explicitly provided to avoid PVC immutability errors
            local.postgresql_storage_class != null ? {
              storageClass = local.postgresql_storage_class
            } : {}
          )
        }
      }

      # Redis configuration (Official Harbor chart)
      redis = {
        type = local.redis_type
        internal = {
          enabled = local.redis_type == "internal" ? true : false
          resources = {
            requests = {
              memory = lookup(local.spec, "redis_memory", "256Mi")
              cpu    = lookup(local.spec, "redis_cpu", "100m")
            }
          }
        }
      }

      # Trivy scanner
      trivy = {
        enabled = local.enable_trivy
      }

      # Core service replicas
      core = {
        replicas = local.replicas
        resources = {
          requests = {
            memory = lookup(local.spec, "core_memory", "512Mi")
            cpu    = lookup(local.spec, "core_cpu", "200m")
          }
        }
      }

      # Portal replicas
      portal = {
        replicas = local.replicas
      }

      # Jobservice replicas
      jobservice = {
        replicas = local.replicas
      }

      # Registry replicas
      registry = {
        replicas = local.replicas
      }

      # Persistence configuration - avoid setting storageClass to prevent PVC immutability errors
      persistence = {
        enabled = true
        persistentVolumeClaim = {
          registry = {
            size = lookup(local.spec, "registry_storage_size", "5Gi")
          }
          jobservice = {
            jobLog = {
              size = lookup(local.spec, "jobservice_storage_size", "1Gi")
            }
          }
          database = {
            size = lookup(local.spec, "database_storage_size", "1Gi")
          }
          redis = {
            size = lookup(local.spec, "redis_storage_size", "1Gi")
          }
          trivy = {
            size = lookup(local.spec, "trivy_storage_size", "5Gi")
          }
        }
      }
    }),
    # User-supplied Helm values - allows full customization and overrides
    yamlencode(local.user_supplied_helm_values)
  ]
}
