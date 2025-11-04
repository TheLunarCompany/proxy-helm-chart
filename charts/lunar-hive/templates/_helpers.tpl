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

{{/*
Resolve ingress domain mappings, defaulting to controller/router/ui hosts when none are provided.
*/}}
{{- define "mcpx-hive.ingress.domains" -}}
{{- if .Values.ingress.domains }}
{{- toYaml .Values.ingress.domains }}
{{- else }}
controller:
  - host: {{ .Values.controller_domain | quote }}
    paths:
      - path: /
        pathType: Prefix
        backend:
          serviceName: "controller"
          servicePort: 80
router:
  - host: {{ .Values.router_domain | quote }}
    paths:
      - path: /
        pathType: Prefix
        backend:
          serviceName: "router"
          servicePort: 9000
ui:
  - host: {{ .Values.ui_domain | quote }}
    paths:
      - path: /
        pathType: Prefix
        backend:
          serviceName: "router"
          servicePort: 5173
{{- end }}
{{- end }}

{{/*
GCP-specific ingress resources (ManagedCertificate, FrontendConfig, BackendConfig)
*/}}
{{- define "ingress.gcp.resources" -}}
{{- $fullname := include "mcpx-hive.fullname" . }}
{{- $domains := fromYaml (include "mcpx-hive.ingress.domains" .) }}
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: {{ printf "%s-cert" $fullname }}
  labels:
    name: {{ printf "%s-cert" $fullname }}
    app: {{ printf "%s-cert" $fullname }}
spec:
  domains:
    {{- range $key, $value := $domains }}
    {{- range $value }}
    - {{ .host }}
    {{- end }}
    {{- end }}

---
apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: {{ printf "%s-frontendconfig" $fullname }}
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: "302"

---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: {{ printf "%s-backendconfig" $fullname }}
  labels:
    name: {{ printf "%s-backendconfig" $fullname }}
    app: {{ printf "%s-backendconfig" $fullname }}
spec:
  timeoutSec: 3600
  connectionDraining:
    drainingTimeoutSec: 60
  sessionAffinity:
    affinityType: "CLIENT_IP"
    affinityCookieTtlSec: 3600
  healthCheck:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 1
    unhealthyThreshold: 3
    type: HTTP
    requestPath: /health
    port: 9000

---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: {{ printf "%s-websocket-backendconfig" $fullname }}
  labels:
    name: {{ printf "%s-websocket-backendconfig" $fullname }}
    app: {{ printf "%s-websocket-backendconfig" $fullname }}
spec:
  timeoutSec: 3600
  connectionDraining:
    drainingTimeoutSec: 60
  sessionAffinity:
    affinityType: "CLIENT_IP"
    affinityCookieTtlSec: 3600
  healthCheck:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 1
    unhealthyThreshold: 3
    type: HTTP
    requestPath: /health
    port: 5173
{{- end }}

{{/*
GCP-specific ingress annotations
*/}}
{{- define "ingress.gcp.annotations" -}}
{{- $fullname := include "mcpx-hive.fullname" . }}
kubernetes.io/ingress.class: "gce"
{{- if .Values.ingress.gcp.staticIPName }}
networking.gke.io/static-ip: {{ .Values.ingress.gcp.staticIPName }}
kubernetes.io/ingress.global-static-ip-name: {{ .Values.ingress.gcp.staticIPName }}
{{- end }}
networking.gke.io/managed-certificates: {{ printf "%s-cert" $fullname }}
networking.gke.io/v1beta1.FrontendConfig: {{ printf "%s-frontendconfig" $fullname }}
cloud.google.com/backend-config: '{"default": "{{ printf "%s-backendconfig" $fullname }}"}'
{{- end }}

{{/*
AWS-specific ingress annotations
*/}}
{{- define "ingress.aws.annotations" -}}
{{- $fullname := include "mcpx-hive.fullname" . }}
kubernetes.io/ingress.class: "alb"
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
{{- if .Values.ingress.aws.loadBalancerType }}
alb.ingress.kubernetes.io/load-balancer-name: {{ printf "%s-alb" $fullname }}
{{- end }}
{{- if .Values.ingress.aws.securityGroups }}
alb.ingress.kubernetes.io/security-groups: {{ join "," .Values.ingress.aws.securityGroups }}
{{- end }}
{{- if .Values.ingress.aws.subnets }}
alb.ingress.kubernetes.io/subnets: {{ join "," .Values.ingress.aws.subnets }}
{{- end }}
{{- if .Values.ingress.aws.elasticIPs }}
alb.ingress.kubernetes.io/eip-allocations: {{ join "," .Values.ingress.aws.elasticIPs }}
{{- end }}
{{- if .Values.ingress.aws.certificateArn }}
alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.aws.certificateArn }}
{{- end }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'
{{- end }}

{{/*
Azure-specific ingress annotations
*/}}
{{- define "ingress.azure.annotations" -}}
kubernetes.io/ingress.class: "azure/application-gateway"
{{- if .Values.ingress.azure.applicationGatewayName }}
appgw.ingress.kubernetes.io/application-gateway-name: {{ .Values.ingress.azure.applicationGatewayName }}
{{- end }}
{{- if .Values.ingress.azure.resourceGroup }}
appgw.ingress.kubernetes.io/resource-group: {{ .Values.ingress.azure.resourceGroup }}
{{- end }}
{{- if .Values.ingress.azure.subscriptionId }}
appgw.ingress.kubernetes.io/subscription-id: {{ .Values.ingress.azure.subscriptionId }}
{{- end }}
{{- if .Values.ingress.azure.staticIP }}
appgw.ingress.kubernetes.io/static-ip: {{ .Values.ingress.azure.staticIP }}
{{- end }}
appgw.ingress.kubernetes.io/ssl-redirect: "true"
{{- end }}
