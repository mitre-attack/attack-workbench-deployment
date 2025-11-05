# ATT&CK Workbench Kubernetes Deployment

<div style="background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 4px; padding: 15px; margin-bottom: 20px;">
  <strong>⚠️ Work in Progress</strong><br>
  These Kubernetes templates are a work in progress and are not guaranteed to work out of the box. Please review and customize all configurations before deploying to your environment.
</div>

This directory contains Kubernetes manifests for deploying ATT&CK Workbench using Kustomize.

## Prerequisites

- Kubernetes cluster
- `kubectl` configured to access your cluster
- Kustomize (built into most versions of `kubectl`)
- Persistent storage class available in your cluster

## Architecture

The deployment consists of:

- **Frontend**: Angular SPA served by Nginx
- **REST API**: Express.js API server
- **TAXII Server**: Nest.js TAXII 2.1 compliant server (optional)
- **Database**: MongoDB StatefulSet with persistent storage

## Quick Start

### Development Deployment

```bash
# Deploy to development environment
kubectl apply -k k8s/overlays/dev

# Check deployment status
kubectl get pods -n attack-workbench

# Access the application (if using LoadBalancer)
kubectl get svc -n attack-workbench dev-attack-workbench-frontend
```

### Production Deployment

```bash
# Deploy to production environment
kubectl apply -k k8s/overlays/prod

# Check deployment status
kubectl get pods -n attack-workbench

# Access the application
kubectl get svc -n attack-workbench prod-attack-workbench-frontend
```

## Configuration

`dev` and `prod` overlay templates are provided. They will probably not work out-of-the-box. Before deploying with `kubectl`, review the ConfigMaps and Kustomization overlays for accuracy.

- **Dev overlay** (`overlays/dev/`):
  - Debug logging enabled
  - CORS enabled for development
  - Single replica for all services
  - Uses `latest` image tags

- **Prod overlay** (`overlays/prod/`):
  - Production logging levels
  - Multiple replicas for high availability
  - Higher resource limits
  - Uses `stable` image tags (these tags don't exist; we recommend changing to a semver release)
  - HTTPS enabled for TAXII server

### Customization

To customize the deployment for your environment:

1. **Storage**: Update the StorageClass in `base/statefulset-mongodb.yaml`
2. **Images**: Modify image tags in the respective overlay kustomization.yaml
3. **Resources**: Adjust CPU/memory limits in deployment files
4. **Configuration**: Update ConfigMaps for service-specific settings

## Accessing Services

### Port Forward for Development

```bash
# Frontend
kubectl port-forward -n attack-workbench svc/dev-attack-workbench-frontend 8080:80

# REST API
kubectl port-forward -n attack-workbench svc/dev-attack-workbench-rest-api 3000:3000

# TAXII Server
kubectl port-forward -n attack-workbench svc/dev-attack-workbench-taxii 5002:5002
```

### Ingress (Recommended for Production)

For production deployments, consider setting up an Ingress controller:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: attack-workbench-ingress
  namespace: attack-workbench
spec:
  rules:
  - host: workbench.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prod-attack-workbench-frontend
            port:
              number: 80
```

## Maintenance

### Backup MongoDB Data

```bash
# Create backup job
kubectl create job --from=cronjob/mongodb-backup manual-backup -n attack-workbench
```

### Update Deployment

```bash
# Update images
kubectl set image deployment/prod-frontend frontend=ghcr.io/center-for-threat-informed-defense/attack-workbench-frontend:v1.2.3 -n attack-workbench

# Or redeploy with updated manifests
kubectl apply -k k8s/overlays/prod
```

### Scale Services

```bash
# Scale REST API
kubectl scale deployment prod-rest-api --replicas=3 -n attack-workbench
```

## Troubleshooting

### Check Pod Logs

```bash
# Frontend logs
kubectl logs -l app=frontend -n attack-workbench

# REST API logs
kubectl logs -l app=rest-api -n attack-workbench

# Database logs
kubectl logs -l app=mongodb -n attack-workbench
```

### Check Service Connectivity

```bash
# Test internal service connectivity
kubectl run test-pod --image=busybox -i --tty --rm -n attack-workbench -- /bin/sh

# Inside the pod:
nslookup attack-workbench-database
wget -qO- http://attack-workbench-rest-api:3000/api/health/ping
```
