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

    Make a curl request to the openapi endpoint exposed by quarkus-smallrye-openapi.

    ```bash
    curl http://localhost:8080/q/openapi
    curl "http://localhost:8080/q/openapi?format=json" | jq
    ```

    Open your browser and navigate to the Swagger UI to see a human-readable version of the documentation.

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

    **Test the Endpoint with Invalid Data**

    Let's see what happens when we send an invalid request.

    Go to the Swagger UI: [http://localhost:8080/q/swagger-ui](http://localhost:8080/q/swagger-ui)

    -   Expand the `POST /stops` endpoint.
    -   Click "Try it out".
    -   Modify the request body to be invalid. For example, send an empty `stationId` or a `null` `arrivalTime`.

        ```json
        {
          "stationId": "",
          "arrivalTime": null
        }
        ```
    -   Click "Execute".

    You will likely see a `500 Internal Server Error`. The response body might show a `ConstraintViolationException` from the database, because we are trying to insert invalid data. This is not a user-friendly response. We should return a `400 Bad Request` instead, just like the OpenAPI documentation said we would.

6.  **Add Jakarta Validation and Document Entity Schema**

    Add the `quarkus-hibernate-validator` dependency to your `pom.xml`.

    ```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-hibernate-validator</artifactId>
    </dependency>
    ```

    Annotate the `TrainStop` entity with Jakarta Validation constraints and OpenAPI schema properties.

    ```java
    // src/main/java/com/example/TrainStop.java
    import jakarta.validation.constraints.NotBlank;
    import jakarta.validation.constraints.NotNull;

    @Entity
    @Schema(name = "TrainStop", description = "Represents a scheduled stop for a train line.")
    public class TrainStop extends PanacheEntity {
        @Schema(description = "The ID of the station where the train stops", example = "station-1")
        @NotBlank(message = "Station ID must not be blank")
        public String stationId;
        @Schema(description = "The scheduled arrival time at the station in ISO 8601 format", example = "2025-09-16T10:00:00Z")
        @NotNull(message = "Arrival time must not be null")
        public Instant arrivalTime;
    }
    ```

    Annotate the TrainStop parameters in the `TrainStopResource` to accept only valid stops.

    ```java
    // ...
    @POST
    @Transactional
    public Response create(@Valid TrainStop trainStop) {
        // ...

    @PUT
    @Path("/{id}")
    @Transactional
    public TrainStop update(@PathParam("id") Long id, @Valid TrainStop newTrainStop) {
        // ...
    ```

    Refresh the Swagger UI and retest invalid the updated schema for `TrainStop`, including validation rules and examples.

    Retest some invalid TrainStops to see how the API responds.

7.  **Save your work**

    Commit your changes to git.

    ```bash
    git add .
    git commit -m "feat: Lab 4 complete - OpenAPI documentation"
    ```

## Final Check

- [ ] Can you access the Swagger UI and see your documentation?
- [ ] Does the documentation correctly reflect the `201` and `200` response codes for your `create` endpoint?
- [ ] Does the documentation correctly reflect the `400` response code for your `create` and `update` endpoints?
- [ ] Have you committed your work to Git?

## Discussion Points
- [Quarkus OpenAPI and Swagger](https://quarkus.io/guides/openapi-swaggerui)
- [Jakarta WS Specification](https://jakarta.ee/specifications/restful-ws/4.0/)
- [OpenAPI Specification](https://swagger.io/specification/)
- [Microprofile OpenAPI](https://microprofile.io/specifications/open-api/)
- [SmallRye OpenAPI implementation](https://github.com/smallrye/smallrye-open-api)