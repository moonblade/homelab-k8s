# BASE INFRASTRUCTURE

## OVERVIEW

Reusable infrastructure bases. Cluster overlays reference these via kustomize.

## STRUCTURE

```
base/
└── infra/
    ├── authentik/              # SSO provider
    ├── cert-manager/           # TLS certificates (Let's Encrypt)
    ├── cilium/                 # CNI (disabled in sirius)
    ├── external-dns/           # Cloudflare DNS automation
    ├── flannel/                # CNI alternative (disabled)
    ├── gateway-api-crds/       # Gateway API CRDs
    ├── ingress-nginx/          # Ingress controller
    ├── kubernetes-dashboard/   # Dashboard UI
    ├── longhorn/               # Storage (disabled - had issues)
    ├── metallb/                # Bare-metal load balancer
    ├── nginx-gateway-fabric/   # Gateway API implementation
    ├── sealed-secrets/         # Bitnami SealedSecrets controller
    └── weave-gitops/           # GitOps UI
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add infra component | `infra/<component>/kustomization.yaml` | Then add overlay in cluster |
| HelmRelease pattern | `infra/sealed-secrets/helm-release.yaml` | Reference for Helm-based infra |
| HelmRepository | `infra/*/repo.yaml` or `helm-repo.yaml` | Chart source definitions |
| Namespace resource | `infra/*/namespace.yaml` | Some components declare explicitly |

## CONVENTIONS

- **kustomization.yaml**: Groups resources, sets namespace
- **helm-release.yaml**: Flux HelmRelease for chart-based installs
- **helm-repo.yaml / repo.yaml**: HelmRepository or OCIRepository for chart sources
- **namespace.yaml**: Explicit namespace when needed (labels, annotations)

## HOW OVERLAYS WORK

Cluster references base:
```yaml
# clusters/sirius/infra/<component>/kustomization.yaml
resources:
- ../../../../base/infra/<component>
- ./secret-sealed.yaml  # cluster-specific
- ./dnsendpoints.yaml   # cluster-specific
```

## ANTI-PATTERNS

- **DO NOT put cluster-specific config here** - belongs in cluster overlay
- **DO NOT hardcode secrets** - use SealedSecret references in overlays
- **DO NOT mix Helm versions** - standardize HelmRelease apiVersion

## NOTES

- Most components installed via HelmRelease (external charts)
- Bases are generic; cluster-specific values go in overlay
- Two ingress controllers exist (nginx + gateway-fabric) - pick one per cluster
