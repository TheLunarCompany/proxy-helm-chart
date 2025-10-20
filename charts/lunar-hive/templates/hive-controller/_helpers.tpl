{{/*
Expand the name of the chart.
*/}}
{{- define "mcpx-hive.hive-controller.name" -}}
{{- default "hive-controller" .Values.hiveController.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mcpx-hive.hive-controller.fullname" -}}
{{- if .Values.hiveController.fullnameOverride }}
{{- .Values.hiveController.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "hive-controller" .Values.hiveController.nameOverride }}
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
{{- define "mcpx-hive.hive-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mcpx-hive.hive-controller.labels" -}}
helm.sh/chart: {{ include "mcpx-hive.hive-controller.chart" . }}
{{ include "mcpx-hive.hive-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mcpx-hive.hive-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcpx-hive.hive-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mcpx-hive.hive-controller.serviceAccountName" -}}
{{- if .Values.hiveController.serviceAccount.create }}
{{- default (include "mcpx-hive.hive-controller.fullname" .) .Values.hiveController.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.hiveController.serviceAccount.name }}
{{- end }}
{{- end }} 