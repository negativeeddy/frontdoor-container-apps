Param(
  [Parameter(Mandatory = $true)]
  [string] $BASE_NAME,
  [string] $LOCATION = "southcentralus"
)

## Resource Group & Deployment
$RESOURCE_GROUP_NAME="$BASE_NAME-rg"
$uniqueSuffix = get-date -format FileDateTimeUniversal
$DEPLOYMENT_NAME="$BASE_NAME-deployment-$uniqueSuffix"

## Register Providers
az provider register --wait --namespace Microsoft.App
az provider register --wait --namespace Microsoft.ContainerService
az provider register --wait --namespace Microsoft.Cdn

## Create Resource Group
az group create `
    --name $RESOURCE_GROUP_NAME `
    --location $LOCATION

## Deploy Template$
$RESULT = az deployment group create `
    --resource-group $RESOURCE_GROUP_NAME `
    --name $DEPLOYMENT_NAME `
    --template-file main.bicep `
    --parameters baseName=$BASE_NAME `
    --query properties.outputs.result `
    | ConvertFrom-Json

## Output Result
$PRIVATE_LINK_ENDPOINT_CONNECTION_ID = $RESULT.value.privateLinkEndpointConnectionId
$FQDN = $RESULT.value.fqdn
$PRIVATE_LINK_SERVICE_ID = $RESULT.value.privateLinkServiceId

# FALLBACK: Private Link Service approval
# if ([string]::IsNullOrEmpty($PRIVATE_LINK_ENDPOINT_CONNECTION_ID)) {
#     write-output "Failed to get privateLinkEndpointConnectionId"
#     while ([string]::IsNullOrEmpty($PRIVATE_LINK_ENDPOINT_CONNECTION_ID)) {
#         write-output "- retrying..."
#         $PRIVATE_LINK_ENDPOINT_CONNECTION_ID = $(az network private-endpoint-connection list --id $PRIVATE_LINK_SERVICE_ID --query "[0].id" -o tsv)
#         start-sleep 5
#     }
# }

## Approve Private Link Service
write-output "Private link endpoint connection ID: $PRIVATE_LINK_ENDPOINT_CONNECTION_ID"
az network private-endpoint-connection approve --id $PRIVATE_LINK_ENDPOINT_CONNECTION_ID --description "(Frontdoor) Approved by CI/CD"

write-output "...Deployment FINISHED!"
write-output "Please wait a few minutes until endpoint is established..."
write-output "--- FrontDoor FQDN: https://$FQDN ---"