# Lab 5: Securing and Consuming a Protected API

## Objective

In this lab, you will learn how to secure your `train-line-service` using Keycloak. You will also learn how to consume a protected API from another microservice, the `station-service`, which is a key part of our Smart City Transit Network.

## Theme Integration

As the `train-line-service`, you will need to retrieve data from a centralized `station-service`. This data is sensitive and must be protected. You will configure your service to act as a client of a Keycloak server to get an access token and then use that token to make a secure call to the `station-service`.

## Instructions

### Step 1: Add Dependencies

Open your `pom.xml` file and add the following extensions:

-   `quarkus-oidc`: To secure the service's own endpoints.
-   `quarkus-oidc-client`: Provides the capability to fetch tokens from an OIDC provider.
-   `quarkus-rest-client-oidc-filter`: Automatically applies the OIDC token to outgoing REST Client requests.
-   `quarkus-rest-client-jackson`: To create the type-safe REST client interface.

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-oidc</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-oidc-client</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest-client-oidc-filter</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest-client-jackson</artifactId>
</dependency>
```

### Step 2: Configure Keycloak

Open your `application.properties` file and add the following configuration. This tells your service how to connect to the Keycloak server.

```properties
# Keycloak Configuration
quarkus.oidc.auth-server-url=http://localhost:8082/realms/smart-city
quarkus.oidc.client-id=train-line-service
quarkus.oidc.credentials.secret=**********
```

- `auth-server-url`: The URL of the Keycloak server
- `client-id`: the identification used by our train-line-service when contacting the OIDC server (keycloak)
- `credentials.secret`: The secret key used by your service to authenticate to keycloak (often provided as an injected external configuration secret through environment variables)

### Step 3: Secure the API

Open your `TrainStopResource.java` and add the `@RolesAllowed` annotation to protect the `list` endpoint. This will ensure that only users with the `admin` role can access it.

```java
// src/main/java/com/example/TrainStopResource.java
// ...
import jakarta.annotation.security.RolesAllowed;

@Path("/stops")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TrainStopResource {

    // ...

    @GET
    @RolesAllowed("admin")
    public List<TrainStop> list() {
        return TrainStop.listAll();
    }

    // ...
}
```

Run the application in dev mode. Trying to access the `/stops` endpoint should now result in a `401 Unauthorized` error.

```bash
curl -v http://localhost:8080/stops
```

### Step 4: Consume the `station-service`

First, deploy the provided `station-service` container.

#### Create a REST Client

Define a JAX-RS interface for the `station-service`.

```java
// src/main/java/com/example/StationService.java
package com.example;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;
import java.util.List;

@RegisterRestClient
@Path("/stations")
public interface StationService {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    List<Station> getAllStations();

    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    Station getStationById(@PathParam("id") String id);
}
```

#### Create a Data Transfer Object

Add a `Station` object to represent the data you will retrieve.

```java
// src/main/java/com/example/Station.java
package com.example;

public class Station {
    public String id;
    public String name;
    public String location;
}
```

#### Inject and Use the REST Client

In your `TrainStopResource.java`, inject the `StationService` and use it to enrich your `TrainStop` data.

```java
// src/main/java/com/example/TrainStopResource.java
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;
import jakarta.inject.Inject;
// ...

@Path("/stops")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TrainStopResource {

    private static final Logger LOG = Logger.getLogger(TrainStopResource.class);

    @Inject
    @RestClient
    StationService stationService;

    // ...
    @POST
    @Transactional
    public Response create(TrainStop trainStop) {
        TrainStop existingStop = TrainStop.find("stationId = ?1 and arrivalTime = ?2", trainStop.stationId, trainStop.arrivalTime).firstResult();
        if (existingStop != null) {
            return Response.ok(existingStop).build();
        }

        // Enrich train stop details
        Station station = stationService.getStationById(trainStop.stationId);
        LOG.infof("Found station: %s", station.name);
        
        trainStop.persist();
        return Response.status(Response.Status.CREATED).entity(trainStop).build();
    }
}
```

#### Configure the REST Client URL

In `application.properties`, tell Quarkus how to configure the `station-service` rest client.

Add the configuration for authenticating with the station-service:

```properties
# StationService Configuration
station-service/mp-rest/url=http://localhost:8081
station-service/mp-rest/token-client = station-service
```

- `url`: url where the station-service is available
- `token-client`: This tells the REST client, "Before you make a request, you must first acquire a Bearer token. Use the OIDC client configuration named station-service to get that token." This property links the REST client to the outbound security configuration below.

```properties
# OIDC Client Configuration (for outbound requests to station-service)
quarkus.oidc-client.station-service.auth-server-url=${quarkus.oidc.auth-server-url}
quarkus.oidc-client.station-service.client-id=${quarkus.oidc.client-id}
quarkus.oidc-client.station-service.credentials.secret=${quarkus.oidc.credentials.secret}
quarkus.oidc-client.station-service.grant.type=client
quarkus.oidc-client.station-service.audience=station-service
```

- `auth-server-url`: The URL of the Keycloak server (referencing the same as previously)
- `client-id`: The identification used to identify our service with the station-service.
- `credentials.secret`: secret used specifically when contacting the station-service. In our scenario it's the same as one used to connect to keycloak.
- `grant.type`: Which OAuth 2.0 flow to use. In this case it's the standard Client Credentials grant for service-to-service communication.
- `audience`: Indicates which audience is targeted for this token request. This instructs Keycloak to issue a token which contains an audience claim for `station-service`

### Step 5: Test with `curl`

You will need a valid JWT token from Keycloak to test the secured endpoints.

First fetch the Bearer token from the Keycloak server.

```bash
BEARER_TOKEN=$(curl -sS -X POST \
    http://localhost:8082/realms/smart-city/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \                                    
    -d "client_id=train-cli" \ 
    -d "username=operator" \
    -d "password=croce" | jq -r '.access_token')
```

The above command will make the request, use jq to pull only the Bearer token from the response, and store it to the `BEARER_TOKEN` variable.

Now make a request to create a new stop, passing the `BEARER_TOKEN` in the `Authorization` header.

```bash
curl -v -X POST \                
  -H "Content-Type: application/json" \                                    
  -H "Authorization: Bearer ${BEARER_TOKEN}" \            
  -d '{"stationId": "1", "arrivalTime": "2025-09-16T10:00:00Z"}' \
  "http://localhost:8080/stops"
```

If everything is configured as it should be, you should receive a `201 Created` response. Run it again and you'll have the `200 OK` response.

### Step 6: Save your work

Commit your changes to Git.

```bash
git add .
git commit -m "feat: Lab 5 complete - security and rest client"
```

## Final Check

- [ ] Is your `TrainStopResource` protected with the `@RolesAllowed` annotation?
- [ ] Can you call the `station-service` and retrieve data to enrich your `TrainStop`?
- [ ] Have you committed your work to Git?

## Discussion Points

- [Quarkus Security](https://quarkus.io/guides/security)
- [OIDC Bearer Token Authentication in Quarkus](https://quarkus.io/guides/security-oidc-bearer-token-authentication#overview-of-the-bearer-token-authentication-mechanism-in-quarkus)
- [OIDC Authorization Code Flow](https://quarkus.io/guides/security-oidc-code-flow-authentication-tutorial)
