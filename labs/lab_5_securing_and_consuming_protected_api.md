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
quarkus.oidc.credentials.secret=train-service-secret
```

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

In `application.properties`, tell Quarkus where to find the `station-service`.

```properties
# Rest Client Configuration
com.example.StationService/mp-rest/url=http://localhost:8081
```

### Step 5: Test with `curl`

You will need a valid JWT token from Keycloak to test the secured endpoints.

**TODO**: Add `curl` commands for testing the secured `create` and `list` endpoints.

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