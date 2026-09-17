# tethysapp-helm-library

Reusable Helm charts for deploying [Tethys Platform](https://www.tethysplatform.org/) apps on Kubernetes, independent of any single portal or project.

## Charts

- [`charts/tethys-app`](charts/tethys-app) — deploy one Tethys app (single-app mode) or a portal (multi-app), on the `tethys-uvx` image family. Config-as-code, hook-Job provisioning, optional ingress/IRSA/HPA/PDB and bundled Postgres/Valkey.

## Usage

```bash
helm install my-app charts/tethys-app -f my-values.yaml
```

See each chart's README for values and examples. Charts target the `tethys-uvx` image for flexibility and scale-out (single fixed serving port, idempotent provisioning decoupled from replicas).

Compute add-ons like a Dask cluster are left to the consuming app, since not every app needs them; the app's `serviceAccount` (IRSA) is reused by those resources.

## Roadmap

- Gateway API routing as an alternative to Ingress.
