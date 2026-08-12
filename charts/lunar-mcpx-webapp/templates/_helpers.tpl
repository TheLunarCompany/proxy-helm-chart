{{/*
Expand the name of the chart.
*/}}
{{- define "lunar-mcpx-webapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "lunar-mcpx-webapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "lunar-mcpx-webapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve MCPX version for UI and SERVER tag/env: global.mcpxVersion override falls back to chart mcpxVersion annotation.
*/}}
{{- define "lunar-mcpx-webapp.mcpxVersion" -}}
{{- $global := .Values.global -}}
{{- coalesce $global.mcpxVersion .Chart.Annotations.mcpxVersion -}}
{{- end }}

{{/*
Default registry base paths per group and environment. When a group's selector
(global.webappRepository / global.mcpxRepository) is "dev" or "boomipoc", the
prod base path below is replaced (plain string replacement) with the selected
environment's base path inside each service's image.repository — everything
after the base (image name and any sub-path) is preserved. The dev/boomipoc
bases can be overridden with global.webappRepositoryDev / global.mcpxRepositoryDev
and global.webappRepositoryBoomipoc / global.mcpxRepositoryBoomipoc.
*/}}
{{- define "lunar-mcpx-webapp.webappRepositoryProd.default" -}}us-central1-docker.pkg.dev/prj-common-442813/lunar-private{{- end -}}
{{- define "lunar-mcpx-webapp.webappRepositoryDev.default" -}}us-central1-docker.pkg.dev/prj-common-442813/lunar-playground{{- end -}}
{{- define "lunar-mcpx-webapp.webappRepositoryBoomipoc.default" -}}us-central1-docker.pkg.dev/prj-common-442813/lunar-boomi-poc{{- end -}}
{{- define "lunar-mcpx-webapp.mcpxRepositoryProd.default" -}}us-central1-docker.pkg.dev/prj-common-442813/mcpx{{- end -}}
{{- define "lunar-mcpx-webapp.mcpxRepositoryDev.default" -}}us-central1-docker.pkg.dev/prj-common-442813/mcpx-dev{{- end -}}
{{- define "lunar-mcpx-webapp.mcpxRepositoryBoomipoc.default" -}}us-central1-docker.pkg.dev/prj-common-442813/mcpx-boomi-poc{{- end -}}

{{/*
Resolve a webapp image repository based on global.webappRepository.
- "prod" (default): use the service's configured image.repository as-is.
- "dev": replace the prod base path with the dev base path (string replacement).
- "boomipoc": replace the prod base path with the boomipoc base path (string replacement).
  Repositories that don't contain the prod base are left unchanged.
Usage:
{{ include "lunar-mcpx-webapp.webappImage" (dict "repo" .Values.webserver.image.repository "context" .) }}
*/}}
{{- define "lunar-mcpx-webapp.webappImage" -}}
{{- $selector := .context.Values.global.webappRepository | default "prod" -}}
{{- if eq $selector "dev" -}}
{{- $prodBase := include "lunar-mcpx-webapp.webappRepositoryProd.default" .context -}}
{{- $devBase := .context.Values.global.webappRepositoryDev | default (include "lunar-mcpx-webapp.webappRepositoryDev.default" .context) -}}
{{- .repo | replace $prodBase $devBase -}}
{{- else if eq $selector "boomipoc" -}}
{{- $prodBase := include "lunar-mcpx-webapp.webappRepositoryProd.default" .context -}}
{{- $boomipocBase := .context.Values.global.webappRepositoryBoomipoc | default (include "lunar-mcpx-webapp.webappRepositoryBoomipoc.default" .context) -}}
{{- .repo | replace $prodBase $boomipocBase -}}
{{- else -}}
{{- .repo -}}
{{- end -}}
{{- end -}}

{{/*
Resolve an mcpx image repository based on global.mcpxRepository.
- "prod" (default): use the provided image.repository as-is.
- "dev": replace the prod base path with the dev base path (string replacement).
- "boomipoc": replace the prod base path with the boomipoc base path (string replacement).
  Repositories that don't contain the prod base are left unchanged.
Usage:
{{ include "lunar-mcpx-webapp.mcpxImage" (dict "repo" .Values.ui.image.repository "context" .) }}
*/}}
{{- define "lunar-mcpx-webapp.mcpxImage" -}}
{{- $selector := .context.Values.global.mcpxRepository | default "prod" -}}
{{- if eq $selector "dev" -}}
{{- $prodBase := include "lunar-mcpx-webapp.mcpxRepositoryProd.default" .context -}}
{{- $devBase := .context.Values.global.mcpxRepositoryDev | default (include "lunar-mcpx-webapp.mcpxRepositoryDev.default" .context) -}}
{{- .repo | replace $prodBase $devBase -}}
{{- else if eq $selector "boomipoc" -}}
{{- $prodBase := include "lunar-mcpx-webapp.mcpxRepositoryProd.default" .context -}}
{{- $boomipocBase := .context.Values.global.mcpxRepositoryBoomipoc | default (include "lunar-mcpx-webapp.mcpxRepositoryBoomipoc.default" .context) -}}
{{- .repo | replace $prodBase $boomipocBase -}}
{{- else -}}
{{- .repo -}}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "lunar-mcpx-webapp.labels" -}}
helm.sh/chart: {{ include "lunar-mcpx-webapp.chart" . }}
{{ include "lunar-mcpx-webapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lunar-mcpx-webapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lunar-mcpx-webapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "lunar-mcpx-webapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "lunar-mcpx-webapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "lunar-mcpx-webapp.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{/*
ClickHouse connection URL built at runtime via K8s variable substitution.
CLICKHOUSE_USER and CLICKHOUSE_PASSWORD must be available via envFrom.
*/}}
{{- define "lunar-mcpx-webapp.clickhouseUrl" -}}
http://$(CLICKHOUSE_USER):$(CLICKHOUSE_PASSWORD)@{{ include "lunar-mcpx-webapp.fullname" . }}-clickhouse:8123
{{- end }}

{{/*
Redis env for the AI gateway.

REDIS_URL and the cluster flag arrive through the -embedded Secret on envFrom,
the same source every other service reads them from. That Secret carries the
flag as both REDIS_IS_CLUSTER for the Node services and REDIS_USE_CLUSTER for
this engine, so nothing sets it here: a container's own `env` overrides
`envFrom` and would shadow the Secret. With Redis from outside the chart the
Secret is the operator's own and carries only the Node spelling, so the $(VAR)
alias derives this engine's name from it, resolved by the kubelet against the
envFrom values the same way CLICKHOUSE_URL is.

The retry knobs are set always. Each is a bare strconv.Atoi over the raw env
value whose parse failure is a log.Panic, and the ai-gateway image carries no
defaults for them. They are inert when no URL is set.
*/}}
{{- define "lunar-mcpx-webapp.gatewayRedisEnv" -}}
{{- $redis := .Values.gateway.redis }}
{{- if not (.Values.redis.enabled | default false) }}
- name: REDIS_USE_CLUSTER
  value: "$(REDIS_IS_CLUSTER)"
{{- end }}
- name: REDIS_MAX_RETRY_ATTEMPTS
  value: {{ $redis.maxRetryAttempts | toString | quote }}
- name: REDIS_MAX_OPTIMISTIC_LOCKING_RETRY_ATTEMPTS
  value: {{ $redis.maxOptimisticLockingRetryAttempts | toString | quote }}
- name: REDIS_RETRY_BACKOFF_MILLIS
  value: {{ $redis.retryBackoffMillis | toString | quote }}
{{- with $redis.prefix }}
- name: REDIS_PREFIX
  value: {{ . | quote }}
{{- end }}
{{- end }}

{{- define "lunar-mcpx-webapp.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{/*
Prisma pool env vars from a service's values (e.g. .Values.hub).
Unset knobs are omitted so the service falls back to Prisma defaults.
Usage:
{{- include "lunar-mcpx-webapp.dbPoolEnv" .Values.hub | nindent 12 }}
*/}}
{{- define "lunar-mcpx-webapp.dbPoolEnv" -}}
{{- with .db }}
{{- with .connectionLimit }}
- name: DB_CONNECTION_LIMIT
  value: {{ . | quote }}
{{- end }}
{{- with .poolTimeoutSeconds }}
- name: DB_POOL_TIMEOUT_SECONDS
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}
