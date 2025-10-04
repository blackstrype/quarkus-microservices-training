# Keycloak Local Setup Instructions

## Objective

This document outlines the steps for setting up a local Keycloak server using Podman. This environment will be used to test the security features of the `train-line-service` and to give you hands-on experience before the training such that you'll be able to properly seamlessly operate and setup of the OIDC service for the Day 2 lab.

## Instructions

1. **Understand what's being configured**

    This Keycloak configuration file, `smart-city-realm.json`, is a pre-configured setup for the "Smart City Transit Network" application. It establishes a security realm named `smart-city` that defines all the necessary users, roles, and clients (which represent our microservices) to enable secure communication between them.

Here's a breakdown of what it configures:

- **Realm:** A realm in Keycloak manages a set of users, credentials, roles, and clients. The `smart-city` realm isolates our application's security configuration.

- **Clients:** Clients are applications and services that can request authentication. This configuration defines two primary clients:
    - `station-service`: Represents the service that manages station data.
    - `train-line-service`: Represents the train line microservices that participants will build.
    - `train-cli`: Represents a public client application that be used to for the OIDC client login flow (in our case `curl`)

- **Roles:** It creates roles for authorization, such as `admin` and `operator`. These roles are assigned to users or service accounts to grant them specific permissions within the application.

- **Service Accounts:** It creates special "service account" users for both the `station-service` and `train-line-service`. This allows these microservices to communicate with each other securely (machine-to-machine communication) without needing a human user to log in.

- **Client Scopes:** It defines a custom scope called `station-service-access`. The `train-line-service` is configured to request this scope by default. When it authenticates, Keycloak will issue an access token that includes this scope, signaling that the `train-line-service` is authorized to access the `station-service`.

- **Groups:** In our case, it provides pre-configured role-mappings, such that any users that are members inherit the role-mapping.

By importing this file, you are automating the entire security setup, allowing you to focus on developing the microservices themselves.

2.  **Run Keycloak with Podman**

    From the keycloak directory. Use Podman to run the Keycloak server in development mode, exposing it on port 8082 and pre-configuring it with the `smart-city-realm.json` file. The `-e KEYCLOAK_ADMIN=scott` and `-e KEYCLOAK_ADMIN_PASSWORD=messner` flags set the initial admin credentials.

    ```bash
    podman run -p 8082:8080 -e KEYCLOAK_ADMIN=scott -e KEYCLOAK_ADMIN_PASSWORD=messner -v ./smart-city-realm.json:/opt/keycloak/data/import/smart-city-realm.json quay.io/keycloak/keycloak:22.0.1 --verbose start-dev --import-realm
    ```

    Once the server is running, open your browser, navigate to the administration console, and log in with user:password `scott:messner`.

    [http://localhost:8082](http://localhost:8082)

3.  **Create the User used for creating train stops**

    - Make sure you are in the "smart-city" realm.
    - In the left-hand menu, click "Users".
    - Click "Add user".
    - Provide a username (e.g., `operator`).
    - Click "Join Groups", select the "train-line-operators" group, and click "Join".
    - Navigate to the "Credentials" tab and set a password. Disable "Temporary" to prevent the user from being forced to change the password on their first login.

4.  **Test the Bearer Token request using curl**

    Request a Bearer Token for the `operator` user.

    ```bash
    BEARER_TOKEN=$(curl -sS -X POST \
        http://localhost:8082/realms/smart-city/protocol/openid-connect/token \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=train-cli" \
        -d "username=operator" \
        -d "password=croce" | jq -r '.access_token')

    echo $BEARER_TOKEN
    ```
    
    Use the obtained Bearer token to create a new train stop (you should have a `201` response).

    ```bash
    curl -v -X POST \                
        -H "Content-Type: application/json" \                 
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        -d '{"stationId": "1", "arrivalTime": "2025-09-16T10:00:00Z"}' \
        http://localhost:8080/stops
    ```

## Final Check

- [ ] Can you log into the Keycloak admin console?
- [ ] Can you create the operator user?
- [ ] Is the `train-operator` role created and assigned correctly?
- [ ] Can you fetch the Bearer token for the `operator` user ?
- [ ] Can you successfully create a new train stop?
