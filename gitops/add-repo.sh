#!/bin/bash

# Script to add GitHub repository to Argo CD
# Usage: ./add-repo.sh <GITHUB_TOKEN>

if [ -z "$1" ]; then
  echo "Usage: ./add-repo.sh <GITHUB_TOKEN>"
  echo "Get your token from: https://github.com/settings/tokens"
  exit 1
fi

GITHUB_TOKEN="$1"
REPO_URL="https://github.com/EiconVision/eicon-gitops.git"

# Create the repository secret
kubectl create secret generic eicon-gitops-repo \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url="$REPO_URL" \
  --from-literal=password="$GITHUB_TOKEN" \
  --from-literal=username=git \
  --dry-run=client -o yaml | \
kubectl label -f - argocd.argoproj.io/secret-type=repository --local -o yaml | \
kubectl apply -f -

echo "Repository added! Check Argo CD UI or run: kubectl get applications -n argocd"