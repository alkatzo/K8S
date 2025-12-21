{{/* Image reference helper */}}
{{- define "image" -}}
{{ .Values.registry }}/{{ .Values.repository }}:{{ . }}
{{- end -}}

{{/* PostgreSQL connection helpers */}}
{{- define "postgres.host" -}}
postgres-service.{{ . }}.svc.cluster.local
{{- end -}}

{{- define "postgres.env" -}}
- name: POSTGRES_HOST
  value: {{ include "postgres.host" . | quote }}
- name: POSTGRES_PORT
  value: "5432"
- name: POSTGRES_DB
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_DB
- name: POSTGRES_USER
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_USER
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      key: POSTGRES_PASSWORD
{{- end -}}
