# Harbor Container Registry - Helm Module

This Facets module deploys Harbor Container Registry on Kubernetes using the official Harbor Helm chart.

## Overview

Harbor is an open-source container registry that secures artifacts with policies and role-based access control. This module deploys Harbor with:

- **Internal PostgreSQL database** for metadata storage
- **Internal Redis** for caching and job queues
- **Trivy vulnerability scanner** for image security scanning
- **Ingress support** for external access
- **Persistent storage** for registry data and database

## Architecture

The module deploys the following Harbor components:

1. **Core** - Main Harbor API and web UI
2. **Portal** - Harbor web interface
3. **Registry** - Docker registry for storing container images
4. **Jobservice** - Manages Harbor jobs (replication, scanning, etc.)
5. **Database (PostgreSQL)** - Stores Harbor metadata
6. **Redis** - Caching and job queue
7. **Trivy** - Container image vulnerability scanner

## Prerequisites

- Kubernetes cluster (via `kubernetes_cluster` input)
- Storage class available for persistent volumes
- Ingress controller (if using ingress expose type)
- DNS record pointing to your cluster's ingress IP

## Configuration

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `registry_domain` | string | Domain name for Harbor registry (e.g., `harbor.example.com`) |
| `admin_password` | string | Admin password for Harbor (should be a secret reference) |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `admin_username` | string | `admin` | Admin username for Harbor |
| `storage_size` | string | `50Gi` | Storage size for persistent volumes |
| `expose_type` | string | `ingress` | How to expose Harbor (`ingress`, `loadbalancer`, `nodeport`) |
| `ingress_class_name` | string | `nginx` | Ingress class name |
| `namespace` | string | `harbor` | Kubernetes namespace for Harbor |
| `chart_version` | string | `1.14.0` | Harbor Helm chart version |
| `enable_https` | boolean | `true` | Enable HTTPS for Harbor |
| `enable_trivy` | boolean | `true` | Enable Trivy scanner |
| `database_type` | string | `internal` | Database type (`internal` or `external`) |
| `redis_type` | string | `internal` | Redis type (`internal` or `external`) |
| `replicas` | number | `1` | Number of replicas for Harbor components |

## Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `kubernetes_cluster` | `@outputs/kubernetes-cluster` | Yes | Kubernetes cluster to deploy Harbor |

## Outputs

| Output | Description |
|--------|-------------|
| `registry_url` | Full URL to access Harbor registry |
| `registry_domain` | Domain name of the registry |
| `namespace` | Kubernetes namespace where Harbor is deployed |
| `admin_username` | Harbor admin username |
| `helm_release_name` | Name of the Helm release |
| `helm_release_status` | Status of the Helm release |

## Usage Example

```json
{
  "kind": "harbor-registry",
  "flavor": "helm",
  "version": "1.0",
  "disabled": false,
  "spec": {
    "registry_domain": "harbor.example.com",
    "admin_password": "${blueprint.self.secrets.harbor_admin_password}",
    "admin_username": "admin",
    "storage_size": "100Gi",
    "expose_type": "ingress",
    "ingress_class_name": "nginx",
    "namespace": "harbor",
    "chart_version": "1.14.0",
    "enable_https": true,
    "enable_trivy": true,
    "database_type": "internal",
    "redis_type": "internal",
    "replicas": 2
  },
  "inputs": {
    "kubernetes_cluster": {
      "resource_name": "production-cluster",
      "resource_type": "kubernetes_cluster"
    }
  }
}
```

## Critical Fix

**Issue**: The original module had an empty `main.tf` file, causing Harbor to deploy without the PostgreSQL database StatefulSet. This resulted in crashlooping Harbor core and jobservice pods.

**Solution**: This updated module includes:
1. Proper `helm_release` resource in `harbor-helm.tf`
2. Explicit database configuration with `enabled = true` for internal database
3. Complete Helm values for all Harbor components
4. Resource requests and persistence configuration

## Troubleshooting

### Pods in CrashLoopBackOff

**Symptom**: Harbor core or jobservice pods crash with database connection errors.

**Cause**: Database StatefulSet not deployed or not ready.

**Solution**:
1. Check if database pod exists: `kubectl get pods -n harbor | grep database`
2. Verify database service: `kubectl get svc -n harbor | grep database`
3. Check database logs: `kubectl logs -n harbor <database-pod-name>`

### PVC Pending

**Symptom**: Persistent Volume Claims remain in Pending state.

**Cause**: No storage class available or insufficient storage.

**Solution**:
1. Check storage classes: `kubectl get sc`
2. Verify PVC status: `kubectl get pvc -n harbor`
3. Increase `storage_size` parameter if needed

### Ingress Not Working

**Symptom**: Cannot access Harbor via domain name.

**Cause**: DNS not configured or ingress controller missing.

**Solution**:
1. Verify ingress: `kubectl get ingress -n harbor`
2. Check ingress controller: `kubectl get pods -n ingress-nginx`
3. Confirm DNS resolution: `nslookup <registry_domain>`

## Security Considerations

1. **Always use secrets** for `admin_password` - never hardcode passwords
2. **Enable HTTPS** in production environments
3. **Configure RBAC** in Harbor after deployment
4. **Enable Trivy scanning** to detect vulnerabilities
5. **Regular backups** of database and registry storage
6. **Network policies** to restrict access to Harbor components

## Upgrade Notes

To upgrade Harbor:
1. Update `chart_version` parameter
2. Review Harbor release notes for breaking changes
3. Backup database before upgrade
4. Test in non-production environment first

## Support

For issues or questions:
- Harbor documentation: https://goharbor.io/docs/
- Helm chart: https://github.com/goharbor/harbor-helm
