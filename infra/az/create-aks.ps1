param(
  [string]$ResourceGroup = "devops-rg",
  [string]$ClusterName   = "devops-aks",
  [string]$Location      = "eastus",
  [int]$NodeCount        = 1
)

$ErrorActionPreference = "Stop"

Write-Host "🔐 Logging in (a browser window may open)..." -ForegroundColor Cyan
az login | Out-Null

Write-Host "📦 Creating resource group '$ResourceGroup' in '$Location'..." -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location | Out-Null

Write-Host "☸️  Creating AKS cluster '$ClusterName' (this can take a few minutes)..." -ForegroundColor Cyan
az aks create `
  --resource-group $ResourceGroup `
  --name $ClusterName `
  --node-count $NodeCount `
  --enable-addons monitoring `
  --generate-ssh-keys | Out-Null

Write-Host "🔗 Fetching kubeconfig for kubectl..." -ForegroundColor Cyan
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing | Out-Null

Write-Host "✅ Done! Your AKS cluster is ready." -ForegroundColor Green
kubectl get nodes
