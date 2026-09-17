# tethysapp-helm-library

Reusable Helm charts for deploying [Tethys Platform](https://www.tethysplatform.org/) apps on Kubernetes, independent of any single portal or project.

## Charts

- [`charts/tethys-app`](charts/tethys-app) — deploy one Tethys app (single-app mode) or a portal (multi-app), on the `tethys-uvx` image family. Config-as-code, hook-Job provisioning, optional ingress/IRSA/HPA/PDB and bundled Postgres/Valkey.

## Usage

Install straight from the GHCR OCI registry (pinned to a version):

```bash
helm install my-app oci://ghcr.io/aquaveo/charts/tethys-app --version 0.1.0 -f my-values.yaml
```

Or as a dependency in a consuming chart:

```yaml
dependencies:
  - name: tethys-app
    version: 0.1.0
    repository: oci://ghcr.io/aquaveo/charts
```

Local checkout works too:

```bash
helm install my-app charts/tethys-app -f my-values.yaml
```

See each chart's README for values and examples. Charts target the `tethys-uvx` image for flexibility and scale-out (single fixed serving port, idempotent provisioning decoupled from replicas).

## Publishing

Pushing a `v*.*.*` tag runs `.github/workflows/publish-chart.yaml`, which packages `charts/tethys-app` at the tag version and pushes it to `oci://ghcr.io/aquaveo/charts`. Bump `version` in `charts/tethys-app/Chart.yaml`, then tag to match:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

Compute add-ons like a Dask cluster are left to the consuming app, since not every app needs them; the app's `serviceAccount` (IRSA) is reused by those resources.

## Roadmap

- Gateway API routing as an alternative to Ingress.
