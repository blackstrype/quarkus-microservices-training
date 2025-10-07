# Sample commands to interact with the secured train-line-service API

# Export the IP and Port of the services
export TRAIN_LINE_IP_AND_PORT=$(kubectl get service train-line-service -n quarkus-lab-environment -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):80
export KEYCLOAK_IP_AND_PORT=$(kubectl get service keycloak -n quarkus-lab-environment -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080

# Get a Bearer Token from Keycloak for the operator user
BEARER_TOKEN=$(curl -sS -X POST \
    http://${KEYCLOAK_IP_AND_PORT}/realms/smart-city/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=train-cli" \
    -d "username=operator" \
    -d "password=croce" | jq -r '.access_token')

# Alternatively, get a Bearer Token from Keycloak for the admin user
# This user can be used to test the protected list endpoint
BEARER_TOKEN=$(curl -sS -X POST \
    http://${KEYCLOAK_IP_AND_PORT}/realms/smart-city/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=train-cli" \
    -d "username=scott" \
    -d "password=smessner" | jq -r '.access_token')

# Create a new stop
curl -v \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${BEARER_TOKEN}" \
  -d '{"stationId": "1", "arrivalTime": "2025-09-16T10:00:00Z"}' \
  "http://${TRAIN_LINE_IP_AND_PORT}/stops"

# Get the list of stops
curl -v \                                                                                                                       
  -H "Authorization: Bearer ${BEARER_TOKEN}" \            
  "http://${TRAIN_LINE_IP_AND_PORT}/stops"


# Login to ACR
export ACR_REFRESH_TOKEN=$(az acr login --name acrquarkustraining20250925 --expose-token | jq -r .refreshToken)
podman login acrquarkustraining20250925-fndyedgwgjbredff.azurecr.io -u 00000000-0000-0000-0000-000000000000 -p $ACR_REFRESH_TOKEN

# Set the current namespace to lab-environment
kubectl config set-context --current --namespace=quarkus-lab-environment

# Deploy the train-line-service (to the current namespace)
kubectl apply -f target/kubernetes/kubernetes.yml