{{- define "store-app.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "store-app.fullname" -}}
{{- printf "%s-%s" (include "store-app.name" .) .Release.Name -}}
{{- end -}}
