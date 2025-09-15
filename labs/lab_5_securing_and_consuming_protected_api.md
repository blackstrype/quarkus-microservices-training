Lab 5: Securing and Consuming a Protected API
Objective
In this lab, you will learn how to secure your train-line-service using Keycloak. You will also learn how to consume a protected API from another microservice, the station-service, which is a key part of our Smart City Transit Network.

Theme Integration
As the train-line-service, you will need to retrieve data from a centralized station-service. This data is sensitive and must be protected. You will configure your service to act as a client of a Keycloak server to get an access token and then use that token to make a secure call to the station-service.

Instructions
Step 1: Add Dependencies
Open your pom.xml file.

You need four key extensions to make this work:

quarkus-rest-client-jackson: To create the REST client interface.

quarkus-oidc: To secure the service's own endpoints (optional, but typical).

quarkus-oidc-client: Provides the underlying capability to fetch tokens.

quarkus-rest-client-oidc-filter: The crucial extension that automatically links the REST client to the OIDC client using the @OidcClientFilter annotation.

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

Step 2: Configure Keycloak
Open your application.properties file.

Add the following Keycloak configuration properties. These tell your service how to connect to the Keycloak server and what its client ID and secret are.

# Keycloak Configuration
quarkus.oidc.auth-server-url=http://localhost:8082/realms/smart-city
quarkus.oidc.client-id=train-line-service
quarkus.oidc.credentials.secret=train-service-secret

Step 3: Secure the API
Open your TrainStopResource.java and add the @RolesAllowed annotation to protect the list endpoint. This will ensure that only users with the train-line role can access it.

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
        return trainStopService.findAll();
    }

    // ...
}

Run the application in dev mode and try to access the /stops endpoint. It will fail with a 401 Unauthorized error, which is the expected behavior.

Step 4: Consume the station-service
Deploy the provided station-service container

Create a REST Client. Define a JAX-RS interface for the station-service.

// src/main/java/com/example/StationService.java
package com.example;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@RegisterRestClient
@Path("/stations")
public interface StationService {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    List<Station> getAllStations();

    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    Station getStationById(@PathParam("id") Long id);
}

Add a new Station object. We need a simple data object to represent the stations we will retrieve from the station-service.

// src/main/java/com/example/Station.java
package com.example;

public class Station {
    public Long id;
    public String name;
    public String location;
}

Inject the REST Client. In your TrainStopResource.java, inject the new StationService to call the station-service and retrieve the station data.

// src/main/java/com/example/TrainStopResource.java
import org.eclipse.microprofile.rest.client.inject.RestClient;
// ...

@Path("/stops")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TrainStopResource {

    @Inject
    @RestClient
    StationService stationService;

    // ...
    public Response create(@RequestBody(description = "The train stop to create", required = true, content = @Content(schema = @Schema(implementation = TrainStop.class))) @Valid TrainStop trainStop) {
        TrainStop existingStop = TrainStop.find("stationId = ?1 and arrivalTime = ?2", trainStop.stationId, trainStop.arrivalTime).firstResult();
        if (existingStop != null) {
            return Response.ok(existingStop).build();
        }

        // Enrich train stop details
        Station station = stationService.getStationById(trainStop.stationId);
        log.info(station.toString());
        // Do something incredible with the station data
        trainStop.persist();
        return Response.status(Response.Status.CREATED).entity(trainStop).build();
    }
}

Configure the station-service URL. In application.properties, tell Quarkus where to find the station-service.

# Rest Client Configuration
com.example.StationService/mp-rest/url=http://localhost:8081

Step 5: Run some tests using curl

TODO: Write the tests that cxacreate

Step 6: Save your work
Commit your changes to Git.

git add .
git commit -m "feat: Lab 5 complete - security and rest client"

Final Check
Is your TrainStopResource protected with the @RolesAllowed annotation?

Can you call the /all-stations endpoint and retrieve data from the station-service?

Have you committed your work to Git?