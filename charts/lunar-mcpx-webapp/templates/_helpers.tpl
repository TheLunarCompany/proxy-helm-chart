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
{{- define "lunar-mcpx-webapp.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}
