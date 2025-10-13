locals {
  output_interfaces = {}
  output_attributes = {
    # Primary registry URL - use this to access Harbor UI and API
    registry_url = {
      value     = local.enable_https ? "https://${local.registry_domain}" : "http://${local.registry_domain}"
      sensitive = false
    }

    # Registry domain name - use for DNS configuration or ingress setup
    registry_domain = {
      value     = local.registry_domain
      sensitive = false
    }

    # Internal service endpoints - use for pod-to-pod communication within cluster
    core_service_endpoint = {
      value     = "${helm_release.harbor.name}-core.${local.namespace}.svc.cluster.local"
      sensitive = false
    }

    registry_service_endpoint = {
      value     = "${helm_release.harbor.name}-registry.${local.namespace}.svc.cluster.local"
      sensitive = false
    }

    # Authentication credentials - use for automated Harbor operations
    admin_username = {
      value     = local.admin_username
      sensitive = false
    }

    admin_password = {
      value     = local.admin_password
      sensitive = true
    }

    # Deployment metadata - use for managing Harbor instance
    namespace = {
      value     = local.namespace
      sensitive = false
    }

    helm_release_name = {
      value     = helm_release.harbor.name
      sensitive = false
    }
  }
}