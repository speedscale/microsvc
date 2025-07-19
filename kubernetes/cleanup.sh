#!/bin/bash

# Cleanup Banking Application from Minikube
echo "🧹 Cleaning up Banking Application from Minikube..."

# Delete the namespace (this removes all resources)
kubectl delete namespace banking-app

echo "✅ Cleanup completed!"
echo ""
echo "To completely reset minikube:"
echo "   minikube delete"
echo "   minikube start"