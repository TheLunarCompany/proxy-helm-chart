{{/*
Shared template for admin suspended CronJobs (migrate-status, migrate-rollback-dry, migrate-rollback-execute, migrate-resolve-failed, host-backfill).
Expects a dict with keys:
  - root: top-level Helm context (.)
  - jobName: suffix for the CronJob name and labels
  - command: list of strings for the container command
  - extraEnv: list of {name, value} maps for additional env vars
*/}}
{{- define "lunar-mcpx-webapp.adminCronJob" -}}
{{- $tolerations := concat .root.Values.global.tolerations .root.Values.jobs.tolerations -}}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "lunar-mcpx-webapp.fullname" .root }}-{{ .jobName }}
  labels:
    service: {{ include "lunar-mcpx-webapp.fullname" .root }}-{{ .jobName }}
    {{- with .root.Values.global.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with .root.Values.jobs.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  suspend: true
  schedule: "0 0 31 2 *" # Feb 31 — a date that never exists, so even if accidentally un-suspended, it won't trigger
  jobTemplate:
    spec:
      backoffLimit: 0
      ttlSecondsAfterFinished: 86400
      activeDeadlineSeconds: 3600
      template:
        metadata:
          labels:
            service: {{ include "lunar-mcpx-webapp.fullname" .root }}-{{ .jobName }}
            {{- include "lunar-mcpx-webapp.selectorLabels" .root | nindent 12 }}
            {{- with .root.Values.global.labels }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- with .root.Values.jobs.labels }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
            {{- with .root.Values.jobs.podLabels }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
        spec:
          restartPolicy: Never
          containers:
            - name: {{ .jobName }}
              image: "{{ .root.Values.jobs.image.repository }}:{{ .root.Values.jobs.image.tag | default .root.Values.global.appVersion | default .root.Chart.AppVersion }}"
              command: {{ .command | toJson }}
              {{- if or (.root.Values.global.manageResources.limits) (.root.Values.global.manageResources.requests) }}
              resources:
                {{- if .root.Values.global.manageResources.limits }}
                limits:
                  {{- with .root.Values.jobs.resources.limits }}
                  {{- toYaml . | nindent 18 }}
                  {{- end }}
                {{- end }}
                {{- if .root.Values.global.manageResources.requests }}
                requests:
                  {{- with .root.Values.jobs.resources.requests }}
                    {{- toYaml . | nindent 18 }}
                    {{- end }}
                {{- end }}
              {{- end }}
              envFrom:
                - secretRef:
                    name: {{ include "lunar-mcpx-webapp.fullname" .root }}-embedded
              {{- if and .clickhouse (.root.Values.clickhouse.enabled | default false) }}
                - secretRef:
                    name: {{ .root.Values.clickhouse.credentialsSecret }}
              {{- end }}
              {{- with .root.Values.global.extraEnvFromSecrets }}
              {{- range . }}
                - secretRef:
                    name: {{ . }}
              {{- end }}
              {{- end }}
              {{- with .root.Values.jobs.extraEnvFromSecrets }}
              {{- range . }}
                - secretRef:
                    name: {{ . }}
              {{- end }}
              {{- end }}
              env:
              {{- if and .clickhouse (.root.Values.clickhouse.enabled | default false) }}
                - name: CLICKHOUSE_URL
                  value: "{{ include "lunar-mcpx-webapp.clickhouseUrl" .root }}"
              {{- end }}
              {{- range .extraEnv }}
              {{- if .value }}
                - name: {{ .name }}
                  value: {{ .value | quote }}
              {{- end }}
              {{- end }}
              {{- if .root.Values.global.extraEnvVars }}
              {{- include "lunar-mcpx-webapp.tplvalues.render" (dict "value" .root.Values.global.extraEnvVars "context" .root) | nindent 16 }}
              {{- end }}
              {{- if .root.Values.jobs.extraEnvVars }}
              {{- include "lunar-mcpx-webapp.tplvalues.render" (dict "value" .root.Values.jobs.extraEnvVars "context" .root) | nindent 16 }}
              {{- end }}

          {{- with .root.Values.global.imagePullSecrets }}
          imagePullSecrets:
            {{- range . }}
            - name: {{ . }}
            {{- end }}
          {{- end }}
          {{- with coalesce .root.Values.jobs.nodeSelector .root.Values.global.nodeSelector }}
          nodeSelector:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $tolerations }}
          tolerations:
            {{- toYaml . | nindent 12 }}
          {{- end }}
{{- end }}
