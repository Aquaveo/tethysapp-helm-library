# tethys-app

Generic Helm chart to deploy a [Tethys Platform](https://www.tethysplatform.org/) app, standalone or as part of a portal. Built for the `tethys-uvx` image family (serves on container port 8080, provisions via `/usr/local/bin/provision.sh`).

## What it deploys

- A Tethys `Deployment` + `Service`, config-as-code via a mounted `portal_config.yml` ConfigMap.
- A once-per-release provisioning `Job` (Helm pre-upgrade hook) that waits for the DB, then migrates, collects static, and syncs stores. It runs regardless of replica count, so scaling never races migrations.
- Optional `Ingress`, `ServiceAccount` (IRSA), `PodDisruptionBudget`, `HorizontalPodAutoscaler`, and a created `Secret`.
- Optional bundled `postgresql` and `valkey` subcharts for standalone installs.

## Quick start

```bash
helm dependency build charts/tethys-app   # only if using bundled postgresql/valkey
helm install my-app charts/tethys-app -f my-values.yaml
```

Minimum values:

```yaml
image:
  repository: <registry>/<tethys-uvx-app-image>
  tag: "1.0.0"
tethys:
  mode: single            # single = one app at root; multi = app library
  standaloneApp: my_app    # package name, single mode only
externalDatabase:
  host: my-postgres
secrets:
  existingSecretName: my-app-secrets
ingress:
  enabled: true
  className: alb
  host: my-app.example.org
```

## Required secret keys

Provide these in `secrets.existingSecretName` (or `secrets.create: true` with `secrets.data`):

- `TETHYS_SECRET_KEY`
- `TETHYS_DB_PASSWORD`

App-specific keys (OAuth, cloud storage, etc.) are wired by listing them under `secrets.secretEnv` as `{name, key, optional}`; they resolve from the same Secret.

## Database

Set `externalDatabase.host` (default) to use an existing Postgres, or `postgresql.enabled: true` to bundle one. `valkey.enabled: true` adds a Channels backend; otherwise set it in `portalConfig.settings`.

## Static / media

`s3Static.enabled: true` with a `bucket` serves static and media from object storage (SigV4 presigning). Otherwise Tethys serves them from the persist volume.

## Single-app vs portal

- `tethys.mode: single` sets `MULTIPLE_APP_MODE=False` and `STANDALONE_APP`, serving one app at `/`. Use a subdomain per app; a thin portal can link to them as proxy apps.
- `tethys.mode: multi` serves the app library.

## Settings

`portalConfig.settings` is deep-merged over settings the chart derives from other values (`ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, `DATABASES`, `CHANNEL_LAYERS`, `STORAGES`). Add `INSTALLED_APPS`, `AUTHENTICATION_BACKENDS`, `OAUTH_CONFIG`, etc. there. `tethys.env` adds arbitrary portal env vars.

See `values.yaml` for the full schema and `examples/` for a complete app values file.
