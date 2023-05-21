@help: 
    just --list --unsorted

# Print the definition of COMMAND
@show +COMMAND='':
    just --show {{COMMAND}}

# EKS Workshop
cluster_name := 'eks-workshop'

# Node.js package.json Script Compatibility
export PATH := "./node_modules/.bin:" + env_var('PATH')

_js:
  #!/usr/bin/env node
  console.log('Greetings from JavaScript!')

## AWS CLI ##
[macos]
install-aws-cli:
    brew install awscli
    @echo 
    which aws
    @echo
    aws --version

# Describe an EKS Cluster
describe-cluster EKS_CLUSTER_NAME='eks-workshop':
    aws eks describe-cluster --name {{EKS_CLUSTER_NAME}} | jq

## EKSCTL ##
[macos]
install-eksctl-cli:
    brew tap weaveworks/tap
    brew install weaveworks/tap/eksctl
    @echo
    which eksctl
    @echo
    eksctl version

# Get EKS Node Group
get-nodegroups EKS_CLUSTER_NAME='eks-workshop' +ARGS='':
    eksctl get nodegroup --cluster {{EKS_CLUSTER_NAME}} --output json {{ARGS}} | jq

scale-nodegroup SIZE MIN MAX NAME='managed-ondemand-20230521191515485200000028' EKS_CLUSTER_NAME='eks-workshop' +ARGS='':
    eksctl scale nodegroup \
        --cluster {{EKS_CLUSTER_NAME}} \
        --name {{NAME}} \
        --nodes {{SIZE}} \
        --nodes-min {{MIN}} \
        --nodes-max {{MAX}} \
        {{ARGS}}
    @echo
    @just wait-nodes

## KUBECTL ##

# Show Kubernetes Contexts
get-contexts:
    kubectl config get-contexts

# Use Kubernetes Context
use-context CONTEXT_NAME='eks-workshop':
    kubectl config use-context {{CONTEXT_NAME}}

# Get Kubernetes Nodes
get-nodes +ARGS='':
    kubectl get nodes \
        -o wide \
        --label-columns topology.kubernetes.io/zone \
        {{ARGS}}

# Get Kubernetes Namespaces
get-namespaces +ARGS='':
    kubectl get namespaces {{ARGS}}

# Get Kubernetes Ingress
get-ingress +ARGS='':
    kubectl get ingress {{ARGS}}

# Get Kubernetes Deployments
get-deployments +ARGS='':
    kubectl get deployments {{ARGS}}

# Check rollout status of Kubernetes Deployment
rollout-status DEPLOYMENT +ARGS='':
    kubectl rollout status deployment/{{DEPLOYMENT}} --timeout=180s {{ARGS}} 

# DELETE Kubernetes Deployment
delete-deployment DEPLOYMENT +ARGS='':
    kubectl delete deployment/{{DEPLOYMENT}} {{ARGS}}

# Get Kubernetes Pods
get-pods +ARGS='':
    kubectl get pods {{ARGS}}

describe-pod POD +ARGS='':
    kubectl describe pod/{{POD}} {{ARGS}}

pods-on-nodes +ARGS='':
    kubectl get pods \
        {{ARGS}} \
        -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}'

# Get Kubernetes Services
get-services +ARGS='':
    kubectl get services {{ARGS}}

# Apply Kubernetes Manifests
apply +ARGS='':
    kubectl apply -f {{ARGS}}

# Apply Kustomized Kubernetes Manifests
k-apply +ARGS='':
    kubectl apply -k {{ARGS}}

# Diff Kustomized Kubernetes Manifests
k-diff PATH +ARGS='':
    kubectl diff -k {{PATH}} {{ARGS}} ||:

# Wait for ready nodes
wait-nodes +ARGS='':
    kubectl wait --for=condition=Ready nodes \
        --all \
        --timeout=300s \
        {{ARGS}}

# Wait for ready pods
wait-pods +ARGS='':
    kubectl wait --for=condition=Ready pods \
        --all \
        --timeout=180s \
        {{ARGS}}

# Print Pod Logs (ex. just logs catalog -n catalog)
logs DEPLOYMENT +ARGS='':
    kubectl logs deployment/{{DEPLOYMENT}} \
        --all-containers=true \
        {{ARGS}}

# Print Pod Logs for terminated pods
logs-previous DEPLOYMENT +ARGS='':
    @just logs {{DEPLOYMENT}} \
        --previous \
        {{ARGS}}

# Tail Pod Logs (ex. just logs catalog -n catalog)
tail DEPLOYMENT +ARGS='':
    @just logs {{DEPLOYMENT}} {{ARGS}} -f

# Exec into Pod (ex. just exec catalog -n catalog)
exec DEPLOYMENT +ARGS='':
    kubectl exec -it \
        deployment/{{DEPLOYMENT}} \
        {{ARGS}}

# Scale Kubernetes Deployment to N
scale DEPLOYMENT N +ARGS='':
    kubectl scale \
        deployment/{{DEPLOYMENT}} \
        --replicas={{N}} \
        {{ARGS}}


alias ka  := k-apply
alias ing := get-ingress
alias no  := get-nodes
alias ns  := get-namespaces
alias dep := get-deployments
alias po  := get-pods
alias svc := get-services
