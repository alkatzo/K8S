{{/*
Zone affinity helper - pins pods to specific availability zones
Usage: {{ include "zoneAffinity" (dict "role" $role "Values" $.Values) | nindent 6 }}
*/}}
{{- define "zoneAffinity" -}}
{{- if .Values.enableZoneAffinity }}
{{- $zone := index .Values.zones .role }}
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.kubernetes.io/zone
          operator: In
          values:
          - {{ $zone }}
{{- end }}
{{- end }}
