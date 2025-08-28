param(
  [string]$ResourceGroup = "devops-rg"
)

Write-Host "⚠️ Deleting resource group '$ResourceGroup' (this removes AKS and all resources inside)..." -ForegroundColor Yellow
az group delete --name $ResourceGroup --yes --no-wait
