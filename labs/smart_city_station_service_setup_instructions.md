# Station Service Setup Instructions

## Objective

This document outlines the steps for setting up the `station-service`, a prerequisite for Lab 5. This service will act as a centralized, secure source of truth for all station data in the "Smart City Transit Network."

## Instructions

1.  **Create the Project**

    Use the Quarkus CLI to create a new project named `station-service`. Include the necessary extensions for Panache, the PostgreSQL driver, and security.

    ```bash
    quarkus create app com.example:station-service --extensions=resteasy-reactive,hibernate-orm-panache,jdbc-postgresql,resteasy-reactive-jackson,oidc
    ```

    Navigate to the `station-service` directory.

    ```bash
    cd station-service
    ```

2.  **Create the Panache Entity and Resource**

    Create a `Station` entity that will contain the core station data.

    ```java
    // src/main/java/com/example/Station.java
    package com.example;

    import io.quarkus.hibernate.orm.panache.PanacheEntity;
    import jakarta.persistence.Entity;

    @Entity
    public class Station extends PanacheEntity {
        public String name;
        public String location;
    }
    ```

    Create a `StationResource` that exposes a REST endpoint to retrieve station data. This resource will be protected by Keycloak.

    ```java
    // src/main/java/com/example/StationResource.java
    package com.example;

    import jakarta.annotation.security.RolesAllowed;
    import jakarta.ws.rs.*;
    import jakarta.ws.rs.core.MediaType;
    import jakarta.ws.rs.core.Response;
    import java.util.List;

    @Path("/stations")
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)
    @RolesAllowed("train-line")
    public class StationResource {

        @GET
        public List<Station> list() {
            return Station.listAll();
        }

        @GET
        @Path("/{id}")
        public Station getById(@PathParam("id") Long id) {
            Station station = Station.findById(id);
            if (station == null) {
                throw new NotFoundException();
            }
            return station;
        }
    }
    ```

3.  **Populate the Database**

    Create a file named `import.sql` in `src/main/resources`.

    Add a few sample stations. Quarkus will automatically run this script when the application starts in dev mode.

    ```sql
    insert into Station (id, name, location) values (1, 'Central Station', 'Downtown');
    insert into Station (id, name, location) values (2, 'East Station', 'Eastside');
    insert into Station (id, name, location) values (3, 'West Station', 'Westside');
    ```

4.  **Add Keycloak Security Configuration**

    Add the Keycloak configuration properties to `application.properties`.

    ```properties
    # Keycloak Configuration
    quarkus.oidc.auth-server-url=http://localhost:8080/realms/smart-city
    quarkus.oidc.client-id=station-service
    quarkus.oidc.credentials.secret=station-client-secret
    ```

5.  **Finalize and Deploy**

    Containerize the application.

    ```bash
    ./mvnw package -Pnative -Dquarkus.container-image.build=true
    ```

    Push the image to a container registry.

    ```bash
    podman push example/station-service:1.0.0-SNAPSHOT-runner
    ```

    Provide instructions for participants on how to run the container and connect to the service.

    ```bash
    podman run -it --rm -p 8081:8080 example/station-service:1.0.0-SNAPSHOT-runner
    ```

