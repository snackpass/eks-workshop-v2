@help: 
    just --list --unsorted

# Print the definition of COMMAND
@show +COMMAND='':
    just --show {{ COMMAND }}

# EKS Workshop
kube-context := 'eks-workshop'
kubectl := replace('kubectl --context=_', '_', kube-context)

created-by := '' 
l-created-by := if created-by == '' { '' } else { 
    replace('-l app.kubernetes.io/created-by=_', '_', created-by) 
}

output := 'yaml'
xq := if output == 'yaml' { 'yq' } else { 'jq' }

# Node.js package.json Script Compatibility
export PATH := "./node_modules/.bin:" + env_var('PATH')

# Wow. Possible to shebang in a Justfile.
[private]
js:
  #!/usr/bin/env node
  console.log('Greetings from JavaScript!')

## AWS CLI ##

# Describe an EKS Cluster
describe-cluster JQ_PATTERN='.' EKS_CLUSTER_NAME='eks-workshop' :
    aws eks describe-cluster --name {{ EKS_CLUSTER_NAME }} | {{ xq }} {{ JQ_PATTERN }}

# Describe a Fargate Profile
describe-fargate-profile EKS_FARGATE_PROFILE JQ_PATTERN='.' EKS_CLUSTER_NAME='eks-workshop':
    aws eks describe-fargate-profile \
        --cluster-name {{ EKS_CLUSTER_NAME }} \
        --fargate-profile-name {{ EKS_FARGATE_PROFILE }} \
        --output {{ output }} \
        | {{ xq }} {{ JQ_PATTERN }}

# Describe an EKS Node Group
describe-nodegroup EKS_NODEGROUP_NAME JQ_PATTERN='.' EKS_CLUSTER_NAME='eks-workshop':
    aws eks describe-nodegroup \
        --cluster-name {{ EKS_CLUSTER_NAME }} \
        --nodegroup-name {{ EKS_NODEGROUP_NAME }} \
        --output {{ output }} \
        | {{ xq }} {{ JQ_PATTERN }}

# Update an EKS Managed Node Group
update-nodegroup EKS_NODEGROUP_NAME='managed-ondemand-20230521191515485200000028' EKS_CLUSTER_NAME='eks-workshop':
    aws eks update-nodegroup-version \
        --cluster-name {{ EKS_CLUSTER_NAME }} \
        --nodegroup-name {{ EKS_NODEGROUP_NAME }}
    aws eks wait nodegroup-active \
        --cluster-name {{ EKS_CLUSTER_NAME }} \
        --nodegroup-name {{ EKS_NODEGROUP_NAME }}

# Describe an EKS NLB
describe-load-balancers NAME JQ_PATTERN='.':
    aws elbv2 describe-load-balancers \
        --query {{ replace("'LoadBalancers[?contains(LoadBalancerName, `k8s-_`) == `true`]'", "_", NAME) }} \
        --output {{ output }} \
        | {{ xq }} {{ JQ_PATTERN }}
    
# Descrive the health of an NLB Target Group
describe-target-health NAME JQ_PATTERN='.':
    #!/usr/bin/env bash
    #set -euxo pipefail
    set -euo pipefail
    ALB_ARN=$(aws elbv2 describe-load-balancers \
        --query {{ replace("'LoadBalancers[?contains(LoadBalancerName, `k8s-_`) == `true`]'", "_", NAME) }} \
        | jq -r '.[0].LoadBalancerArn')
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
        --load-balancer-arn ${ALB_ARN} \
        | jq -r '.TargetGroups[0].TargetGroupArn')
    aws elbv2 describe-target-health \
        --target-group-arn $TARGET_GROUP_ARN \
        --output {{ output }} \
        | {{ xq }} {{ JQ_PATTERN }}


## EKSCTL ##

# Get EKS Node Group
get-nodegroups EKS_CLUSTER_NAME='eks-workshop' PATTERN='.' +ARGS='':
    eksctl get nodegroup \
        --cluster {{ EKS_CLUSTER_NAME }} \
        --output {{ output }} \
        {{ ARGS }} \
        | {{ xq }} {{ PATTERN }}

scale-nodegroup SIZE MIN MAX NAME='managed-ondemand-20230521191515485200000028' EKS_CLUSTER_NAME='eks-workshop' +ARGS='':
    eksctl scale nodegroup \
        --cluster {{ EKS_CLUSTER_NAME }} \
        --name {{ NAME }} \
        --nodes {{ SIZE }} \
        --nodes-min {{ MIN }} \
        --nodes-max {{ MAX }} \
        {{ ARGS }}
    @echo
    @just wait-nodes


## KUBECTL ##

# Show Kubernetes Contexts
get-contexts:
    kubectl config get-contexts

# Use Kubernetes Context
use-context CONTEXT_NAME='eks-workshop':
    kubectl config use-context {{ CONTEXT_NAME }}

# Get Kubernetes Nodes
get-nodes +ARGS='':
    {{ kubectl }} get nodes \
        {{ l-created-by }} \
        -o wide \
        --label-columns topology.kubernetes.io/zone \
        --label-columns eks.amazonaws.com/nodegroup \
        {{ ARGS }}

# Describe Kubernetes Nodes
describe-nodes +ARGS='':
    kubectl describe nodes \
        {{ l-created-by }} \
        {{ ARGS }}

# Describe a Kubernetes Node
describe-node NODE +ARGS='':
    kubectl describe node {{ NODE }} {{ ARGS }}

# Get Kubernetes Namespaces
get-namespaces +ARGS='':
    kubectl get namespaces \
        {{ l-created-by }} \
        {{ ARGS }}

# Get Kubernetes Ingress
get-ingress NS='' +ARGS='':
    kubectl get ingress \
        {{ if NS != '' { replace('-n _', '_', NS) } else { '-A' } }} \
        {{ l-created-by }} \
        {{ ARGS }}

# Get Kubernetes Ingress URL
get-ingress-url INGRESS NS='' +ARGS='':
    kubectl get ingress {{ INGRESS }} \
        -n {{ if NS != '' { NS } else { INGRESS} }} \
        -o jsonpath="{.status.loadBalancer.ingress[*].hostname}{'\n'}" \
        {{ ARGS }}

# Get Kubernetes Deployments
get-deployments +ARGS='':
    kubectl get deployments \
        {{ l-created-by }} \
        {{ ARGS }}

# Get a Kuberenetes Deployment
get-deployment DEPLOYMENT NS='' PATTERN='.' +ARGS='':
    kubectl get deployment {{ DEPLOYMENT }} \
        -o {{ output }} \
        -n {{ if NS != '' { NS } else { DEPLOYMENT } }} \
        {{ ARGS }} \
        | {{ xq }} {{ PATTERN }}

get-deployment-env DEPLOYMENT NS='' +ARGS='':
    @just output={{ output }} get-deployment {{ DEPLOYMENT }} \
        {{ if NS != '' { NS } else { DEPLOYMENT } }} \
        "'.spec.template.spec.containers[] | .env'" \
        {{ ARGS }}

# Scale Kubernetes Deployment to N
scale DEPLOYMENT N NS='' +ARGS='':
    kubectl scale \
        deployment/{{ DEPLOYMENT }} \
        -n {{ if NS != '' { NS } else { DEPLOYMENT } }} \
        --replicas={{ N }} \
        {{ ARGS }}

# Check rollout status of Kubernetes Deployment
rollout-status DEPLOYMENT NS='' +ARGS='':
    kubectl rollout status deployment/{{ DEPLOYMENT }} \
        -n {{ if NS != '' { NS } else { DEPLOYMENT} }} \
        --timeout=180s \
        {{ ARGS }} 

# DELETE Kubernetes Deployment
delete-deployment DEPLOYMENT +ARGS='':
    kubectl delete deployment/{{ DEPLOYMENT }} {{ ARGS }}

# Get Kubernetes Pods
get-pods +ARGS='':
    kubectl get pods \
        {{ l-created-by }} \
        {{ ARGS }}

describe-pod POD +ARGS='':
    kubectl describe pod {{ POD }} {{ ARGS }}

pods-on-nodes +ARGS='':
    kubectl get pods \
        {{ l-created-by }} \
        {{ ARGS }} \
        -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}'

# Get Kubernetes Secret value
get-secrets NS NAME='' +ARGS='':
    kubectl get secrets -n {{ NS }} {{ NAME }} \
        {{ ARGS }} 

# Get Kubernetes Secret value
get-secret-value NAME KEY NS='' +ARGS='':
    kubectl get secrets {{ NAME }} \
        -n {{ if NS != '' { NS } else { NAME} }} \
        --template \{\{.data.{{ KEY }}\}\} \
        {{ ARGS }} \
        | base64 -d

# Seal Kubernetes Secret
seal-secret PATH:
    kubeseal --format yaml \
        < {{ PATH }} \
        > {{ replace(PATH, '.yaml', '.sealed.yaml') }}
    @just validate-sealed-secret {{ replace(PATH, '.yaml', '') }}.sealed.yaml

# Unseal Kubernetes Secret
[private]
unseal-secret PATH CERTS:
    @just sealed-secret-validate {{ PATH }}
    kubeseal --recovery-unseal \
        --format yaml \
        --recovery-private-key {{ CERTS }} \
        < {{ PATH }} \
        > {{ replace(PATH, '.sealed.yaml', '') }}.unsealed.yaml

unseal-secret-value KEY PATH CERTS:
    @kubeseal --validate --format yaml < {{ PATH }}
    @kubeseal --recovery-unseal \
        --format yaml \
        --recovery-private-key {{ CERTS }} \
        < {{ PATH }} \
        | yq '.data.{{ KEY }}' \
        | base64 -d \
        | pbcopy
    @echo "Secret value copied to clipboard!"

# Seal Kubernetes Secret
sealed-secret-merge-into KEY PATH:
    #!/usr/bin/env bash
    # Prompt the user for a password
    echo "Please enter the secret value:"

    stty -echo      # Turn off terminal echoing for security
    read value      # Use the read command to get the user input
    stty echo       # Turn terminal echoing back on

    # Pipe the value to kubectl create secret
    echo -n $value \
    | kubectl create secret generic data \
        --dry-run=client --from-file={{ KEY }}=/dev/stdin -o yaml \
    | kubeseal --format yaml \
        --merge-into {{ PATH }}
    
    just sealed-secret-validate {{ PATH }}

# Fetch SealedSecret key
sealed-secret-fetch-key:
    kubectl get secret -l sealedsecrets.bitnami.com/sealed-secrets-key \
        -n kube-system \
        -o yaml > `kubectl config current-context`-sealed-secret.key
    echo Written to `kubectl config current-context`-sealed-secret.key

[private]
sealed-secret-delete-key:
    kubectl delete secret \
        -n kube-system \
        -l sealedsecrets.bitnami.com/sealed-secrets-key
    kubectl delete pod \
        -n kube-system \
        -l name=sealed-secrets-controller
    kubectl wait pods \
        -n kube-system \
        -l name=sealed-secrets-controller \
        --for=condition=Ready \
        --timeout=30s 

[private]
sealed-secret-restore-key PATH:    
    kubectl apply -f {{ PATH }}
    kubectl delete pod \
        -n kube-system \
        -l name=sealed-secrets-controller
    kubectl wait pods \
        -n kube-system \
        -l name=sealed-secrets-controller \
        --for=condition=Ready \
        --timeout=30s 

# Fetch SealedSecret keypair
sealed-secret-fetch-cert:
    kubeseal --fetch-cert \
        --controller-name=sealed-secrets-controller \
        --controller-namespace=kube-system \
        > `kubectl config current-context`-sealed-secret-cert.pem

# Validate Kubernetes SealedSecrets
sealed-secret-validate PATH:
    kubeseal --validate \
        --format yaml \
        < {{ PATH }}

# Get Kubernetes Services
get-services NS='' +ARGS='':
    kubectl get services \
        {{ if NS != '' { replace('-n _', '_', NS) } else { '-A' } }} \
        {{ l-created-by }} \
        {{ ARGS }}

# Describe a Kubernetes Service
describe-service SERVICE NS='' +ARGS='':
    kubectl describe service \
        {{ SERVICE }} \
        -n {{ if NS != '' { NS } else { SERVICE } }} \
        {{ ARGS }}

# Get the public URL of an EKS Service NLB
get-service-lb-url SERVICE NS='' +ARGS='':
    kubectl get service \
        {{ SERVICE }} \
        -n {{ if NS != '' { NS } else { SERVICE } }} \
        -o jsonpath="{.status.loadBalancer.ingress[*].hostname}{'\n'}" \
        {{ ARGS }}

[private]
wait-for-host HOST:
    #!/usr/bin/env bash
    export host={{ HOST }}
    set -Eeuo pipefail
    echo "Waiting for ${host}..."
    EXIT_CODE=0
    timeout --foreground -s TERM 600 bash -c \
        'while [[ "$(curl -s -o /dev/null -L -w ''%{http_code}'' ${host}/home)" != "200" ]]; \
            do sleep 5; \
        done' || EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
    echo "Load balancer did not become available or return HTTP 200 for 600 seconds"
    exit 1
    fi
    echo "You can now access http://${host}"

# Wait for an EKS Service NLB to be ready
wait-for-nlb SERVICE NS='' +ARGS='':
    @just wait-for-host `just get-service-lb-url {{ SERVICE }} {{ NS }}` {{ ARGS }}

# Wait for an EKS Ingress ALB to be ready
wait-for-alb INGRESS NS='' +ARGS='':
    @just wait-for-host `just get-ingress-url {{ INGRESS }} {{ NS }}` {{ ARGS }}

# Apply Kubernetes Manifests
apply PATH +ARGS='':
    kubectl apply -f {{ PATH }} {{ ARGS }}

# Diff Kustomized Kubernetes Manifests
[no-exit-message]
diff PATH +ARGS='':
    kubectl diff -f {{ PATH }} {{ ARGS }}

# Apply Kustomized Kubernetes Manifests
apply-k +ARGS='':
    kubectl apply -k {{ ARGS }}

# Diff Kustomized Kubernetes Manifests
[no-exit-message]
diff-k PATH +ARGS='':
    kubectl diff -k {{ PATH }} {{ ARGS }}

# Wait for ready nodes
wait-nodes +ARGS='':
    kubectl wait --for=condition=Ready nodes \
        --all \
        --timeout=300s \
        {{ ARGS }}

# Wait for ready pods
wait-pods +ARGS='':
    kubectl wait --for=condition=Ready pods \
        --all \
        --timeout=180s \
        {{ ARGS }}

# Print Pod Logs (ex. just logs catalog -n catalog)
logs DEPLOYMENT NS='' +ARGS='':
    kubectl logs deployment/{{ DEPLOYMENT }} \
        -n {{ if NS != '' { NS } else { DEPLOYMENT } }} \
        --all-containers=true \
        {{ ARGS }}

# Print Pod Logs for terminated pods
logs-p DEPLOYMENT NS='' +ARGS='':
    @just logs {{ DEPLOYMENT }} {{ NS }} \
        --previous \
        {{ ARGS }}

# Tail Pod Logs (ex. just logs catalog -n catalog)
tail DEPLOYMENT +ARGS='':
    @just logs {{ DEPLOYMENT }} {{ ARGS }} -f

# Exec into Pod (ex. just exec catalog -n catalog)
exec DEPLOYMENT +ARGS='':
    kubectl exec -it \
        deployment/{{ DEPLOYMENT }} \
        {{ ARGS }}


## Aliases ##

alias ing := get-ingress
alias no  := get-nodes
alias ns  := get-namespaces
alias dep := get-deployments
alias po  := get-pods
alias svc := get-services


## Install CLI Tools ##

[macos]
install-aws-cli:
    brew install awscli
    @echo 
    which aws
    @echo
    aws --version

[macos]
install-eksctl-cli:
    brew tap weaveworks/tap
    brew install weaveworks/tap/eksctl
    @echo
    which eksctl
    @echo
    eksctl version

[macos]
install-jq:
    brew install jq

[macos]
install-yq:
    brew install yq

[macos]
install-kubeseal:
    brew install kubeseal

[linux]
install-kubeseal:
    open https://github.com/bitnami-labs/sealed-secrets#linux
