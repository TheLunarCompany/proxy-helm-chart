{{/*
Expand the name of the chart.
*/}}
{{- define "mcpx-hive.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mcpx-hive.fullname" -}}
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
{{- define "mcpx-hive.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mcpx-hive.labels" -}}
helm.sh/chart: {{ include "mcpx-hive.chart" . }}
{{ include "mcpx-hive.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mcpx-hive.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcpx-hive.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Hive Controller specific labels
*/}}
{{- define "mcpx-hive.hive-controller.labels" -}}
{{ include "mcpx-hive.labels" . }}
app.kubernetes.io/name: hive-controller
{{- end }}

{{/*
Hive Controller selector labels
*/}}
{{- define "mcpx-hive.hive-controller.selectorLabels" -}}
{{ include "mcpx-hive.selectorLabels" . }}
app.kubernetes.io/name: hive-controller
{{- end }}

{{/*
Hive Controller full name
*/}}
{{- define "mcpx-hive.hive-controller.fullname" -}}
{{- printf "%s-controller" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Hive Controller service account name
*/}}
{{- define "mcpx-hive.hive-controller.serviceAccountName" -}}
{{- printf "%s-controller" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Ingress labels
*/}}
{{- define "mcpx-hive.ingress.labels" -}}
{{ include "mcpx-hive.labels" . }}
app.kubernetes.io/name: ingress
{{- end }}

{{/*
Router labels
*/}}
{{- define "mcpx-hive.ingress.router.labels" -}}
{{ include "mcpx-hive.labels" . }}
app.kubernetes.io/name: mcpx-hive-ingress-router
{{- end }}

{{/*
Router selector labels
*/}}
{{- define "mcpx-hive.ingress.router.selectorLabels" -}}
{{ include "mcpx-hive.selectorLabels" . }}
app.kubernetes.io/name: mcpx-hive-ingress-router
{{- end }}

{{/*
Router full name
*/}}
{{- define "mcpx-hive.ingress.router.fullname" -}}
{{- printf "%s-ingress-router" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Router full name (simplified)
*/}}
{{- define "mcpx-hive.router.fullname" -}}
{{- printf "%s-ingress-router" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Router labels
*/}}
{{- define "mcpx-hive.router.labels" -}}
{{ include "mcpx-hive.labels" . }}
app.kubernetes.io/name: router
{{- end }}

{{/*
Router selector labels
*/}}
{{- define "mcpx-hive.router.selectorLabels" -}}
{{ include "mcpx-hive.selectorLabels" . }}
app.kubernetes.io/name: router
{{- end }}
