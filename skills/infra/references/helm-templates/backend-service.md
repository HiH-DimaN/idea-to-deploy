# Helm Template: Backend Service (generic)

> Skeleton used by `/infra` when target is `k8s`. Placeholders in `{{...}}` are replaced at generation time. All best-practice checks from `infra-checklist.md` are enforced (resources, probes, securityContext, networkpolicy, pdb).

## Chart.yaml

```yaml
apiVersion: v2
name: {{service_name}}
description: {{one_line_description}}
type: application
version: 0.1.0
appVersion: "{{app_version}}"
```

## values.yaml (defaults, overridden per env)

```yaml
replicaCount: 2

image:
  repository: {{image_repo}}
  tag: ""              # required per env — never default to latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: {{hostname}}
      paths: [{path: /, pathType: Prefix}]
  tls:
    - hosts: [{{hostname}}]
      secretName: {{service_name}}-tls

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

livenessProbe:
  httpGet:
    path: /livez
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /readyz
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]

autoscaling:
  enabled: false       # disabled in dev
  minReplicas: 2
  maxReplicas: 8
  targetCPUUtilizationPercentage: 70

pdb:
  enabled: false       # requires replicas > 1 + autoscaling
  minAvailable: 1

networkPolicy:
  enabled: true        # default deny + explicit allows
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: ingress-nginx
      ports:
        - port: 8000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - port: 5432
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - port: 6379
    # DNS
    - to:
        - namespaceSelector: {}
      ports:
        - port: 53
          protocol: UDP
```

## values-dev.yaml

```yaml
replicaCount: 1
image:
  tag: "dev"
autoscaling:
  enabled: false
pdb:
  enabled: false
ingress:
  hosts:
    - host: dev.{{hostname}}
```

## values-prod.yaml

```yaml
replicaCount: 2
image:
  tag: "v{{app_version}}"   # semver, NEVER latest
autoscaling:
  enabled: true
pdb:
  enabled: true
  minAvailable: 1
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

## templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "{{service_name}}.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "{{service_name}}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "{{service_name}}.selectorLabels" . | nindent 8 }}
    spec:
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 8000
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          envFrom:
            - secretRef:
                name: {{ include "{{service_name}}.fullname" . }}
```

## templates/pdb.yaml (only if .Values.pdb.enabled)

```yaml
{{- if .Values.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "{{service_name}}.fullname" . }}
spec:
  minAvailable: {{ .Values.pdb.minAvailable }}
  selector:
    matchLabels:
      {{- include "{{service_name}}.selectorLabels" . | nindent 6 }}
{{- end }}
```

## templates/networkpolicy.yaml (only if enabled)

Default deny + explicit ingress from ingress-nginx + egress to declared dependencies (DB, Redis, DNS). Fail the check if this template is missing when `.Values.networkPolicy.enabled` is true.

## README section

```bash
# Install
helm install {{service_name}} ./helm/{{service_name}} \
  -f ./helm/{{service_name}}/values-prod.yaml \
  --namespace {{namespace}}

# Upgrade
helm upgrade {{service_name}} ./helm/{{service_name}} \
  -f ./helm/{{service_name}}/values-prod.yaml

# Rollback
helm rollback {{service_name}} 0

# Lint (required before commit)
helm lint ./helm/{{service_name}}
```
