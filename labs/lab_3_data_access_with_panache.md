# Lab 3: Data Access with Panache

## Objective

In this lab, you will extend your "train line" microservice to handle persistent data. Using Panache, a data access library for Quarkus, you will create a RESTful API to manage the `TrainStop` entities on your train line.

## Theme Integration

Each `TrainStop` represents a specific event for your train line, such as a scheduled arrival time. This is the core data your microservice owns and will manage. The details about the station itself (e.g., name, location) are owned by a separate `StationService` and will be referenced by your `TrainStop` objects.

## Instructions

1.  **Add Dependencies**

    Open your `pom.xml` file.

    Add the `quarkus-hibernate-orm-panache` and a database driver extension. We will use the Quarkus Dev Services for a PostgreSQL database. It's a pragmatic choice for development and testing as it requires no local setup.

    ```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-hibernate-orm-panache</artifactId>
    </dependency>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-jdbc-postgresql</artifactId>
    </dependency>
    ```

    Save the `pom.xml` file. Quarkus will automatically download the new dependencies.

2.  **Write the Failing Test for the `create` operation**

    Create a new test class named `TrainStopResourceTest` in `src/test/java/com/example/`.

    Write a test that will attempt to create a new `TrainStop` object. The test will fail initially because the endpoint doesn't exist yet.

    ```java
    package com.example;

    import io.quarkus.test.junit.QuarkusTest;
    import jakarta.ws.rs.core.MediaType;
    import org.junit.jupiter.api.Test;

    import static io.restassured.RestAssured.given;
    import static org.hamcrest.CoreMatchers.is;
    import static org.hamcrest.Matchers.containsString;

    @QuarkusTest
    public class TrainStopResourceTest {

        @Test
        public void testCreateTrainStop() {
            given()
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                    {
                        "stationId": "station-1",
                        "arrivalTime": "2025-09-16T10:00:00Z"
                    }
                """)
                .when().post("/stops")
                .then()
                .statusCode(201)
                .body("stationId", is("station-1"));
        }
    }
    ```

    Save the file.

3.  **Observe the Test Failure**

    In your terminal, run the application in dev mode.

    ```bash
    ./mvnw quarkus:dev
    ```

    Observe the test failure. It will fail with a `404 Not Found` error because the `/stops` endpoint does not exist yet. This is the expected outcome.

    Leave Quarkus Dev Mode running.

4.  **Write the Production Code for `create`**

    Create a new Java class named `TrainStop` in the `src/main/java/com/example/` directory. This class will be a Panache Entity, so it should extend `PanacheEntity`. Add the following fields: a `stationId` (String) to reference an external station and an `arrivalTime` (Instant).

    ```java
    package com.example;

    import io.quarkus.hibernate.orm.panache.PanacheEntity;
    import jakarta.persistence.Entity;
    import java.time.Instant;

    @Entity
    public class TrainStop extends PanacheEntity {
        public String stationId;
        public Instant arrivalTime;
    }
    ```

    Create a new Java class named `TrainStopResource` in the `src/main/java/com/example/` directory. This class will expose the RESTful API for managing your train line's stops. Implement the `create` method to handle the `POST` request.

    ```java
    package com.example;

    import jakarta.transaction.Transactional;
    import jakarta.ws.rs.*;
    import jakarta.ws.rs.core.MediaType;
    import jakarta.ws.rs.core.Response;

    @Path("/stops")
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)
    public class TrainStopResource {

        @POST
        @Transactional
        public Response create(TrainStop trainStop) {
            trainStop.persist();
            return Response.ok(trainStop).status(201).build();
        }
    }
    ```

    Save the files. Quarkus will automatically re-run the tests, and you will see a successful result in your terminal.

5.  **Write the Remaining Tests and Code**

    Add a test for each of the remaining CRUD operations (list, getById, update, delete). Your `TrainStopResourceTest` class should now look like this:

    ```java
    package com.example;

    import io.quarkus.test.junit.QuarkusTest;
    import jakarta.ws.rs.core.MediaType;
    import org.junit.jupiter.api.BeforeEach;
    import org.junit.jupiter.api.Test;

    import static io.restassured.RestAssured.given;
    import static org.hamcrest.CoreMatchers.is;
    import static org.hamcrest.Matchers.containsString;

    @QuarkusTest
    public class TrainStopResourceTest {

        @BeforeEach
        @Transactional
        public void setup() {
            TrainStop.deleteAll();
        }

        @Test
        public void testCreateTrainStop() {
            given()
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                    {
                        "stationId": "station-1",
                        "arrivalTime": "2025-09-16T10:00:00Z"
                    }
                """)
                .when().post("/stops")
                .then()
                .statusCode(201)
                .body("stationId", is("station-1"));
        }

        @Test
        public void testListAllTrainStops() {
            // We will create some stops first to ensure the list is not empty
            given().contentType("application/json").body("""
            {
              "stationId": "station-2",
              "arrivalTime": "2025-09-16T10:00:00Z"
            }
            """).when().post("/stops").then().statusCode(201);
            given().contentType("application/json").body("""
            {
              "stationId": "station-3",
              "arrivalTime": "2025-09-16T10:05:00Z"
            }
            """).when().post("/stops").then().statusCode(201);

            given()
                    .when().get("/stops")
                    .then()
                    .statusCode(200)
                    .body("size()", is(2));
        }

        @Test
        public void testGetTrainStopById() {
            // First create a stop to update
            String createdStop = given().contentType("application/json").body("""
            {
              "stationId": "station-4",
              "arrivalTime": "2025-09-16T11:00:00Z"
            }
            """).when().post("/stops").then().statusCode(201).extract().asString();
            long stopId = Long.parseLong(createdStop.split(":")[1].split(",")[0]);

            given()
                    .when().get("/stops/" + stopId)
                    .then()
                    .statusCode(200)
                    .body("stationId", is("station-4"));
        }

        @Test
        public void testUpdateTrainStop() {
            // First create a stop to update
            String createdStop = given().contentType("application/json").body("""
            {
              "stationId": "station-5",
              "arrivalTime": "2025-09-16T11:00:00Z"
            }
            """).when().post("/stops").then().statusCode(201).extract().asString();
            long stopId = Long.parseLong(createdStop.split(":")[1].split(",")[0]);

            given()
                    .contentType(MediaType.APPLICATION_JSON)
                    .body("""
                    {
                        "stationId": "station-6",
                        "arrivalTime": "2025-09-16T11:00:00Z"
                    }
                """)
                    .when().put("/stops/" + stopId)
                    .then()
                    .statusCode(200)
                    .body("stationId", is("station-6"));
        }

        @Test
        public void testDeleteTrainStop() {
            // First create a stop to delete
            String createdStop = given().contentType("application/json").body("""
            {
              "stationId": "station-7",
              "arrivalTime": "2025-09-16T12:00:00Z"
            }
            """).when().post("/stops").then().statusCode(201).extract().asString();
            long stopId = Long.parseLong(createdStop.split(":")[1].split(",")[0]);

            given()
                    .when().delete("/stops/" + stopId)
                    .then()
                    .statusCode(204);
        }
    }
    ```

    Implement the remaining CRUD operations in `TrainStopResource.java`.

    ```java
    //... (existing code)

        @GET
        public List<TrainStop> list() {
            return TrainStop.listAll();
        }

        @GET
        @Path("/{id}")
        public TrainStop getById(@PathParam("id") Long id) {
            TrainStop trainStop = TrainStop.findById(id);
            if (trainStop == null) {
                throw new NotFoundException();
            }
            return trainStop;
        }

        @PUT
        @Path("/{id}")
        @Transactional
        public TrainStop update(@PathParam("id") Long id, TrainStop newTrainStop) {
            TrainStop trainStop = TrainStop.findById(id);
            if (trainStop == null) {
                throw new NotFoundException();
            }
            trainStop.stationId = newTrainStop.stationId;
            trainStop.arrivalTime = newTrainStop.arrivalTime;
            trainStop.persist();
            return trainStop;
        }

        @DELETE
        @Path("/{id}")
        @Transactional
        public void delete(@PathParam("id") Long id) {
            TrainStop trainStop = TrainStop.findById(id);
            if (trainStop != null) {
                trainStop.delete();
            }
        }
    ```

6.  **Test the API**

    Use `curl` to interact with your new API.

    Create new train stop:
    ```bash
    curl -X POST -H "Content-Type: application/json" -d '{"stationId": "station-1", "arrivalTime": "2025-09-16T10:00:00Z"}' http://localhost:8080/stops
    curl -X POST -H "Content-Type: application/json" -d '{"stationId": "station-2", "arrivalTime": "2025-09-16T10:30:00Z"}' http://localhost:8080/stops
    ```

    Use `jq` to make the responses more readable:
    ```bash
    curl -X POST -H "Content-Type: application/json" -d '{"stationId": "station-1", "arrivalTime": "2025-09-16T10:00:00Z"}' http://localhost:8080/stops | jq
    ```

    List all train stops:
    ```bash
    curl http://localhost:8080/stops
    ```

    Get a specific train stop by ID:
    ```bash
    curl http://localhost:8080/stops/1
    ```

    Update a train stop:
    ```bash
    curl -X PUT -H "Content-Type: application/json" -d '{"stationId": "station-1", "arrivalTime": "2025-09-16T10:05:00Z"}' http://localhost:8080/stops/1
    ```

    Delete a train stop:
    ```bash
    curl -X DELETE http://localhost:8080/stops/1
    ```

7.  **Save your work**

    Commit your changes to git.

    ```bash
    git add .
    git commit -m "feat: Lab 3 complete - Panache TDD"
    ```

## Final Check

- [ ] Do all your tests for CRUD operations pass?
- [ ] Can you interact with the API using `curl`?
- [ ] Does Quarkus Dev Services start the database correctly?
- [ ] Have you committed your work to Git?

