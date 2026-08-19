{{- define "enrollment.name" -}}
{{ .Chart.Name }}
{{- end -}}
{{- define "enrollment.labels" -}}
app.kubernetes.io/name: {{ include "enrollment.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
{{- define "enrollment.selectorLabels" -}}
app.kubernetes.io/name: {{ include "enrollment.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
