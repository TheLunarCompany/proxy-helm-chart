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

{{/*
CronJob base name.
Returns cronJobBaseName if set, otherwise falls back to the standard fullname.
*/}}
{{- define "lunar-mcpx-webapp.cronJobBaseName" -}}
{{- if .Values.cronJobBaseName -}}
  {{- .Values.cronJobBaseName -}}
{{- else -}}
  {{- include "lunar-mcpx-webapp.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
CronJob name-length validation.
If the computed fullname exceeds 27 characters please supply cronJobBaseName (<= 27 chars).
The 27-char limit exists because the longest CronJob suffix ("-migrate-rollback-execute",
25 chars) plus the base name must fit within the Kubernetes 52-character CronJob name limit.
Only CronJob names are affected; all other resources keep the standard fullname.
*/}}
{{- define "lunar-mcpx-webapp.validateNames" -}}
{{- $fullname := include "lunar-mcpx-webapp.fullname" . -}}
{{- $fullnameLen := int (len $fullname) -}}

{{- if gt $fullnameLen 27 -}}
  {{- if not .Values.cronJobBaseName -}}
    {{- $msg := printf "\n\nVALIDATION ERROR:\nThe computed resource base name '%s' is %d characters long, exceeding the maximum of 27\ncharacters allowed for CronJob base names.\n\nCronJob resources append suffixes up to 25 characters (e.g. '-migrate-rollback-execute').\nCombined with the base name this would exceed Kubernetes' 52-character CronJob name limit.\n\nAll non-CronJob resources are unaffected. To fix this, add 'cronJobBaseName' to your\nvalues file (values.yaml or values-override) with a value up to 27 characters.\nThis value will be used exclusively for CronJob resource names.\n\nCurrent inputs:\n  Release name:      '%s' (%d chars)\n  nameOverride:      '%s' (%d chars)\n  fullnameOverride:  '%s' (%d chars)\n\nExample (add to your values file):\n  cronJobBaseName: \"my-short-name\"\n" $fullname $fullnameLen .Release.Name (len .Release.Name) (default "<not set>" .Values.nameOverride) (len (default "" .Values.nameOverride)) (default "<not set>" .Values.fullnameOverride) (len (default "" .Values.fullnameOverride)) -}}
    {{- fail $msg -}}
  {{- else if gt (int (len .Values.cronJobBaseName)) 27 -}}
    {{- $msg := printf "\n\nVALIDATION ERROR:\ncronJobBaseName '%s' is %d characters long, exceeding the maximum of 27.\nPlease set cronJobBaseName to a value up to 27 characters.\n" .Values.cronJobBaseName (len .Values.cronJobBaseName) -}}
    {{- fail $msg -}}
  {{- end -}}
{{- end -}}
{{- end -}}
