# Lab 4: Documenting Endpoints with OpenAPI

## Objective

In this lab, you will use the SmallRye OpenAPI extension to automatically generate and enrich the API documentation for your `train-line-service`. This will provide a clear contract for other services in the Smart City Transit Network.

## Theme Integration

Microservices need to be able to discover and understand each other's APIs. By documenting your `train-line-service`, you are making it a first-class citizen in the network, ready to be consumed by other services.

## Instructions

1.  **Add the OpenAPI Dependency**

    Open your `pom.xml` file.

    Add the `quarkus-smallrye-openapi` extension.

    ```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-smallrye-openapi</artifactId>
    </dependency>
    ```

    Save the `pom.xml`. Quarkus will automatically download the dependency.

2.  **Observe the Generated Documentation**

    Run the application in dev mode.

    ```bash
    ./mvnw quarkus:dev
    ```

    Open your browser and navigate to the OpenAPI endpoint to see the generated documentation.

    [http://localhost:8080/q/openapi](http://localhost:8080/q/openapi)

    Navigate to the Swagger UI to see a human-readable version of the documentation.

    [http://localhost:8080/q/swagger-ui](http://localhost:8080/q/swagger-ui)

3.  **Add API-level Documentation**

    Annotate your `TrainStopResource` class with a description and tags. This provides a more complete picture of your API.

    ```java
    // src/main/java/com/example/TrainStopResource.java
    import org.eclipse.microprofile.openapi.annotations.tags.Tag;
    import org.eclipse.microprofile.openapi.annotations.tags.Tags;

    @Path("/stops")
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)
    @Tags(value = @Tag(name = "Train Stops", description = "Operations for managing train stops."))
    public class TrainStopResource {
        //...
    }
    ```

    Annotate the `TrainStop` entity. This provides a clear description of the data model.

    ```java
    // src/main/java/com/example/TrainStop.java
    import org.eclipse.microprofile.openapi.annotations.media.Schema;

    @Entity
    @Schema(name = "TrainStop", description = "Represents a scheduled stop for a train line.")
    public class TrainStop extends PanacheEntity {
        // ...
    }
    ```

    Refresh the Swagger UI and observe the new tags and descriptions.

4.  **Document the `create` Endpoint**

    Annotate the `create` endpoint with `@Operation` and `@APIResponse`. This documents the expected behavior of the endpoint.

    ```java
    // src/main/java/com/example/TrainStopResource.java
    import org.eclipse.microprofile.openapi.annotations.Operation;
    import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;

    // ...
    @Operation(summary = "Create a new train stop")
    @APIResponse(responseCode = "201", description = "Train stop created successfully")
    @APIResponse(responseCode = "400", description = "Invalid request payload")
    @POST
    @Transactional
    public Response create(TrainStop trainStop) {
        trainStop.persist();
        return Response.ok(trainStop).status(201).build();
    }
    ```

5.  **Document the Idempotent `create`**

    Update the `create` endpoint to check for an existing `TrainStop`.

    ```java
    // src/main/java/com/example/TrainStopResource.java
    // ...
    @Operation(summary = "Create a new train stop or retrieve an existing one")
    @APIResponse(responseCode = "201", description = "Train stop created successfully")
    @APIResponse(responseCode = "200", description = "Train stop already exists")
    @APIResponse(responseCode = "400", description = "Invalid request payload")
    @POST
    @Transactional
    public Response create(TrainStop trainStop) {
        TrainStop existingStop = TrainStop.find("stationId = ?1 and arrivalTime = ?2", trainStop.stationId, trainStop.arrivalTime).firstResult();
        if (existingStop != null) {
            return Response.ok(existingStop).status(200).build();
        }

        trainStop.persist();
        return Response.ok(trainStop).status(201).build();
    }
    ```

    Refresh the Swagger UI and observe the updated documentation.

6.  **Save your work**

    Commit your changes to git.

    ```bash
    git add .
    git commit -m "feat: Lab 4 complete - OpenAPI documentation"
    ```

## Final Check

- [ ] Can you access the Swagger UI and see your documentation?
- [ ] Does the documentation correctly reflect the `201` and `200` response codes for your `create` endpoint?
- [ ] Have you committed your work to Git?
