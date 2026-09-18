{{- define "tethys-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tethys-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "tethys-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tethys-app.labels" -}}
helm.sh/chart: {{ include "tethys-app.chart" . }}
{{ include "tethys-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "tethys-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tethys-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "tethys-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "tethys-app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "tethys-app.secretName" -}}
{{- if .Values.secrets.existingSecretName -}}
{{- .Values.secrets.existingSecretName -}}
{{- else if .Values.secrets.create -}}
{{- printf "%s-secrets" (include "tethys-app.fullname" .) -}}
{{- else -}}
{{- fail "secrets: set existingSecretName or create=true (needs TETHYS_SECRET_KEY, TETHYS_DB_PASSWORD)" -}}
{{- end -}}
{{- end -}}

{{/* database connection, from a bundled subchart or an external server */}}
{{- define "tethys-app.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- else -}}
{{- .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "tethys-app.dbPort" -}}
{{- if .Values.postgresql.enabled -}}5432{{- else -}}{{- .Values.externalDatabase.port | default 5432 -}}{{- end -}}
{{- end -}}

{{- define "tethys-app.dbName" -}}
{{- if .Values.postgresql.enabled -}}{{- .Values.postgresql.auth.database -}}{{- else -}}{{- .Values.externalDatabase.name -}}{{- end -}}
{{- end -}}

{{- define "tethys-app.dbUser" -}}
{{- if .Values.postgresql.enabled -}}{{- .Values.postgresql.auth.username -}}{{- else -}}{{- .Values.externalDatabase.username -}}{{- end -}}
{{- end -}}

{{/* env shared by the web container and the provision job */}}
{{- define "tethys-app.env" -}}
- name: TETHYS_DB_HOST
  value: {{ include "tethys-app.dbHost" . | quote }}
- name: TETHYS_DB_PORT
  value: {{ include "tethys-app.dbPort" . | quote }}
- name: TETHYS_DB_NAME
  value: {{ include "tethys-app.dbName" . | quote }}
- name: TETHYS_DB_USERNAME
  value: {{ include "tethys-app.dbUser" . | quote }}
- name: PORT
  value: {{ .Values.service.port | quote }}
- name: TETHYS_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "tethys-app.secretName" . }}
      key: TETHYS_SECRET_KEY
- name: TETHYS_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "tethys-app.secretName" . }}
      key: TETHYS_DB_PASSWORD
- name: TETHYS_SETTINGS_FLAGS
  value: "--production --overwrite"
- name: INIT_VERSION
  value: {{ .Values.image.tag | quote }}
{{- if .Values.s3Static.enabled }}
- name: STATIC_S3_BUCKET
  value: {{ .Values.s3Static.bucket | quote }}
- name: AWS_REGION
  value: {{ .Values.s3Static.region | quote }}
{{- with .Values.s3Static.endpointUrl }}
- name: AWS_ENDPOINT_URL
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- range .Values.secrets.secretEnv }}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ include "tethys-app.secretName" $ }}
      key: {{ .key }}
      optional: {{ dig "optional" true . }}
{{- end }}
{{- range $k, $v := .Values.tethys.env }}
- name: {{ $k }}
  {{- if $v.valueFrom }}
  valueFrom:
    {{- toYaml $v.valueFrom | nindent 4 }}
  {{- else }}
  value: {{ $v.value | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/* portal_config settings derived from other chart values */}}
{{- define "tethys-app.portalConfigDerived" -}}
{{- $persist := .Values.tethys.persist.mountPath -}}
{{- if eq .Values.tethys.mode "single" }}
MULTIPLE_APP_MODE: false
{{- with .Values.tethys.standaloneApp }}
STANDALONE_APP: {{ . }}
{{- end }}
{{- end }}
ALLOWED_HOSTS:
  - localhost
  - 127.0.0.1
{{- with .Values.ingress.host }}
  - {{ . }}
{{- end }}
{{- with .Values.ingress.host }}
CSRF_TRUSTED_ORIGINS:
  - {{ $.Values.tethys.publicProtocol }}://{{ . }}
{{- end }}
SECURE_PROXY_SSL_HEADER:
  - HTTP_X_FORWARDED_PROTO
  - https
STATIC_ROOT: {{ $persist }}/static
MEDIA_ROOT: {{ $persist }}/media
TETHYS_WORKSPACES_ROOT: {{ $persist }}/workspaces
DATABASES:
  default:
    ENGINE: django.db.backends.postgresql
    NAME: {{ include "tethys-app.dbName" . }}
    USER: {{ include "tethys-app.dbUser" . }}
    HOST: {{ include "tethys-app.dbHost" . }}
    PORT: {{ include "tethys-app.dbPort" . }}
    CONN_MAX_AGE: 0
{{- if .Values.valkey.enabled }}
CHANNEL_LAYERS:
  default:
    BACKEND: channels_redis.core.RedisChannelLayer
    CONFIG:
      hosts:
        - host: {{ .Release.Name }}-valkey
          port: 6379
{{- end }}
{{- if .Values.s3Static.enabled }}
STORAGES:
  staticfiles:
    BACKEND: storages.backends.s3.S3Storage
    OPTIONS:
      bucket_name: {{ .Values.s3Static.bucket }}
      region_name: {{ .Values.s3Static.region }}
      signature_version: s3v4
      location: static
      querystring_auth: false
      {{- with .Values.s3Static.endpointUrl }}
      endpoint_url: {{ . }}
      {{- end }}
  default:
    BACKEND: storages.backends.s3.S3Storage
    OPTIONS:
      bucket_name: {{ .Values.s3Static.bucket }}
      region_name: {{ .Values.s3Static.region }}
      signature_version: s3v4
      location: media
      querystring_auth: false
      {{- with .Values.s3Static.endpointUrl }}
      endpoint_url: {{ . }}
      {{- end }}
{{- end }}
{{- end -}}

{{/* full portal_config.yml, shared by the ConfigMap and the provision job */}}
{{- define "tethys-app.portalConfigContent" -}}
version: 2.0
name:
apps: {}
settings:
{{ mergeOverwrite (include "tethys-app.portalConfigDerived" . | fromYaml) (.Values.portalConfig.settings | default dict) | toYaml | indent 2 }}
site_settings:
{{ .Values.portalConfig.siteSettings | default dict | toYaml | indent 2 }}
{{- end -}}
