{{/* Коротке ім'я чарта */}}
{{- define "farm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Повне ім'я об'єктів: будується з імені релізу */}}
{{- define "farm.fullname" -}}
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

{{/* Ім'я об'єктів бази даних */}}
{{- define "farm.postgresName" -}}
{{- printf "%s-postgres" (include "farm.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Мітка chart: назва-версія */}}
{{- define "farm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Мітки для вибору подів (selector) */}}
{{- define "farm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "farm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Повний набір міток для всіх об'єктів */}}
{{- define "farm.labels" -}}
helm.sh/chart: {{ include "farm.chart" . }}
{{ include "farm.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Образ застосунку */}}
{{- define "farm.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/* Хост бази даних */}}
{{- define "farm.pgHost" -}}
{{- .Values.config.pgHost | default (include "farm.postgresName" .) }}
{{- end }}

{{/* Ім'я Secret: існуючий або створений чартом */}}
{{- define "farm.secretName" -}}
{{- .Values.secret.existingSecret | default (printf "%s-secret" (include "farm.fullname" .)) }}
{{- end }}

{{/* Шаблон пода застосунку: спільний для Deployment і Rollout */}}
{{- define "farm.webPodTemplate" -}}
metadata:
  labels:
    {{- include "farm.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: web
  annotations:
    # перезапуск подів при зміні конфігурації
    checksum/config: {{ include (print .Template.BasePath "/configmap.yaml") . | sha256sum }}
    {{- if not .Values.secret.existingSecret }}
    checksum/secret: {{ include (print .Template.BasePath "/secret.yaml") . | sha256sum }}
    {{- end }}
spec:
  initContainers:
    - name: wait-for-db
      image: {{ .Values.postgres.image }}
      command: ["sh", "-c", "until pg_isready -h $PG_HOST -p $PG_PORT; do echo waiting for db; sleep 2; done"]
      envFrom:
        - configMapRef:
            name: {{ include "farm.fullname" . }}-config
  containers:
    - name: web
      image: {{ include "farm.image" . }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
      envFrom:
        - configMapRef:
            name: {{ include "farm.fullname" . }}-config
        - secretRef:
            name: {{ include "farm.secretName" . }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      readinessProbe:
        httpGet:
          path: {{ .Values.probes.path }}
          port: http
        initialDelaySeconds: {{ .Values.probes.readinessInitialDelay }}
        periodSeconds: 5
      livenessProbe:
        httpGet:
          path: {{ .Values.probes.path }}
          port: http
        initialDelaySeconds: {{ .Values.probes.livenessInitialDelay }}
        periodSeconds: 10
        failureThreshold: 3
{{- end }}
