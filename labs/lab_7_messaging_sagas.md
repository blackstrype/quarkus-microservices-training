# Lab 7: Asynchronous Messaging with Sagas

## Objective

In this lab, you will refactor the synchronous `train-line-service` logic from Lab 6 into a robust, asynchronous SAGA choreography using messaging. You will decouple the initial API request from the downstream service calls, handle processing asynchronously, and manage data consistency across services.

## Theme Integration

Instead of immediately fetching station details when a `TrainStop` is created, your `train-line-service` will now initiate a SAGA. It will persist the initial stop and send a message to request the station details. A separate consumer will process this request, interact with the `station-service`, and complete the `TrainStop` data asynchronously. This makes your service more resilient and responsive.

![SAGA Choreography Diagram](./images/Lab_7_TrainStop_SAGA.drawio.png)

## Prerequisites

- A running instance of a kafka messaging broker
- Your Quarkus project from the end of Lab 6 (tag solution_lab_6_insecure).
- You have configured your `application.properties` with the connection details for your messaging broker.
- You have started up your local stack (run `./quarkus-microservices-stack/start-lab-7.)

---

## Part 1: The Feature Toggle

### Objective
Create the initial API endpoint that starts the SAGA. The `POST /stops` endpoint will be modified to produce a message instead of synchronously calling the `station-service`.

### Instructions

#### Step 1: Add Dependencies

Open your `pom.xml` file and add the following extensions:

- `quarkus-smallrye-reactive-messaging-kafka`: Provides the connector for kafka brokers like redpanda/apache/confluent.

```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-messaging-kafka</artifactId>
    </dependency>
```

#### Step 1: Prepare for switch to asynchrounous station details requests

Our current functionality makes synchronous calls to the `station-service and applies resiliency patterns on our StationService. Our TrainStopResource tests (especially those of resiliency) are coupled with this functionality. We are changing the contract and introducing breaking changes. In order to prepare for these functional changes we will implement a feature toggle so that our service can continue to work in synchrounous mode and switch over to the new async mode when necessary.

##### Step 1.1: Implement the Async Tests
Start by implementing the new tests. First, add the feature toggle to the application config

```properties
# --- Feature Toggles ---
feature.toggle.station-details-async=true
```

```java
package com.example;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

import java.time.Instant;

/**
 * Groupe of tests for proving the functionality of async creation and update of a TrainStop. For a POST /stops
 * - When a valid TrainStop with a stationId of {x} will return a 202 with the new TrainStop not including the station details of {x}
 * - As part of the request, a station-details-request for the stationId {x} will be sent out
 */
@QuarkusTest
public class TrainStopResourceAsyncTest {

    @Inject
    TrainStopResource trainStopResource;

    @ConfigProperty(name = "feature.toggle.station-details-async", defaultValue = "false")
    boolean stationDetailsAsync;

    @Test
    void testCreateTrainStop() {
        Assumptions.assumeTrue(stationDetailsAsync, "Station details async feature is disabled");

        // Given a valid trainStop:
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();

        // When the trainStop is create is called
        Response result = trainStopResource.create(trainStop);

        /// Then:
        // - A 202 should be received
        Assertions.assertNotNull(result);
        Assertions.assertEquals(???, ???);
        TrainStop resultTrainStop = (TrainStop) result.getEntity();
        Assertions.assertNotNull(resultTrainStop.id);
        Assertions.assertEquals(???, ???);
        // - the trainStop with the resultTrainStop.id should be persisted in the database
        TrainStop persistedTrainStop = ???;
        Assertions.assertNotNull(persistedTrainStop);
        Assertions.assertEquals(trainStop.stationId, persistedTrainStop.stationId);
        // - Note: a station-details-request will be sent out (tested elsewhere)
    }
}
```

##### Step 1.2 Modify the Existing Tests

Modify the `TrainStopResourceTest` so that create calls receive a 202 instead of a 201 when the feature toggle is enabled.

Inject the config property.
```java
    @ConfigProperty(name = "feature.toggle.station-details-async")
    boolean stationDetailsAsync;
    private int expectedCreateStatusCode;
```

Toggle the return code to be used for each test.
```java
    @BeforeEach
    @Transactional
    public void setup()
    {
        // Set the expected status code based on the feature toggle
        expectedCreateStatusCode = stationDetailsAsync ? 202 : 201;
        ...
```

In the create method, use `expectedCreateStatusCode` instead of the static `201`.
```java
@Test
    public void testCreateTrainStop() {
    ...
    .when().post("/stops")
    .then()
    .statusCode(expectedCreateStatusCode)
    ...
```

The other test methods utilize `/create`. Make sure they are also using the `expectedCreateStatusCode` when verifying the response status.
```java
        """
        ...
        """).when().post("/stops").then()
                .statusCode(expectedCreateStatusCode)
                .body("stationId", is("station-2"));
```

Run the tests with the async station details feature toggle disabled. The tests should pass.

```sh
quarkus test -D=feature.toggle.station-details-async=false
```

Now, run the test with the feature toggle enabled (already `true` from your config). The tests should fail.

```sh
quarkus test
```

#### Step 2: Make the Async Tests Pass

Modify the TrainStopResource create method. In order to avoid breaking the current functionality, wrap the existing call in a conditional that will implement async call when the feature is toggled, otherwise the existing implementation is used.
```java
    ...

    @ConfigProperty(name = "feature.toggle.station-details-async", defaultValue = "false")
    boolean featureStationDetailsAsync;
    ...

    public Response create(@Valid TrainStop trainStop) {
        ...
        // Enrich train stop details
        int responseCode = Response.Status.CREATED.getStatusCode();
        if (!this.featureStationDetailsAsync) {
            Station station = stationService.getStationById(trainStop.stationId);
            Log.infof("Found station: %s", station.name);
            // TODO: update trainStop with station details
            trainStop.persist();
        } else {
            trainStop.persist();
            // TODO: request station details
            responseCode = Response.Status.ACCEPTED.getStatusCode();
        }

        return Response.ok(trainStop).status(responseCode).build();
```

Rerun the non-feature-toggled tests. It should pass.
```sh
quarkus test -D=feature.toggle.station-details-async=false
```

Rerun the feature-toggled tests. There are still failures.
```sh
quarkus test
```

The resilience tests still do not work as expected. Because the Resilience tests are specific to the behavior of the TrainStopResource when in synchrounous mode, we will skip these tests when the async feature is toggled.

 ```java
    ...
    @ConfigProperty(name = "feature.toggle.station-details-async", defaultValue = "false")
    boolean stationDetailsAsync;

    // For each test, add a skip directive if the feature is enabled
    ...
    @Test
    void testRetryPolicy_SucceedsOnThirdAttempt() {
        Assumptions.assumeFalse(stationDetailsAsync, "Station details async feature is enabled");
        ...
 ```

The fallback is no-longer working when in async mode. To correct this, we'll toggle the fallback programmatically.

Move the fallback method into a dedicated handler and add the switch logic.
```java
package com.example;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.faulttolerance.ExecutionContext;
import org.eclipse.microprofile.faulttolerance.FallbackHandler;

@ApplicationScoped
public class StationFallbackHandler implements FallbackHandler<Station> {

    @ConfigProperty(name = "feature.toggle.station-details-async", defaultValue = "false")
    boolean stationDetailsAsync;

    @Override
    public Station handle(ExecutionContext context) {
        // If the async feature is enabled, propagate exceptions
        if (stationDetailsAsync) {
            Throwable failure = context.getFailure();
            if (failure instanceof RuntimeException) {
                throw (RuntimeException) failure;
            } else {
                throw new RuntimeException(failure);
            }
        }
        // Otherwise, apply the original fallback logic.
        return StationService.getStationByIdFallback(null);
    }
}
```

Update the StationService interface to use the StationFallbackHandler.
```java
    ...
    @Fallback(StationFallbackHandler.class)
    Station getStationById(@PathParam("id") String id);
    ...
}
```

 Rerun the feature-toggled tests.
```sh
quarkus test
```

#### Step 3: Commit changes

If everything is still working properly between the feature toggle and the previous functionality, commit your changes.

```sh
git add .
git commit "feat: Lab 7 in progress - Implement feature toggle for async station details requests."
```

### Part 2: The SAGA Trigger

#### Objective

Now that our feature toggle is working, we can start introducing the messaging logic the will make the request for station details.

#### Instructions

#### Step 1: Create a Message Producer

Create a new class, `StationDetailsProducer`, to handle sending messages. This class will have an `@Emitter` that sends a request to the `station-details-requests` channel.

```java
package com.example;

import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;

@ApplicationScoped
public class StationDetailsProducer {

    @Inject
    @Channel("station-details-requests-out")
    Emitter<StationDetailsRequestMessage> stationDetailsRequestEmitter;

    public void requestStationDetails(Long trainStopId, String stationId) {
        Log.infof("Requesting station details for trainStop: %d, stationId: %s", trainStopId, stationId);
        stationDetailsRequestEmitter.send(new StationDetailsRequestMessage(trainStopId, stationId));
    }
}
```

We will send a StationDetailsRequestMessage to the `station-details-requests` channel. Implement the StationDetailsRequestMessage record.

```java
package com.example;

public record StationDetailsRequestMessage(Long trainStopId, String stationId) {}
```

#### Step 2: Update the `TrainStopResource`

Add a new field to our TrainStop entity to represent the station details.

```java
    // In TrainStop.java
    ...
    @Schema(description = "The name of the station")
    public String stationName;
```

Inject the `StationDetailsProducer` into your `TrainStopResource`. In the `create` method, after persisting the `TrainStop`, call the producer to send the message.

```java
    // In TrainStopResource.java
    ...
    @Inject
    StationDetailsProducer stationDetailsProducer;

    ...
    // Inside create method
        // Enrich train stop details
        int responseCode = Response.Status.CREATED.getStatusCode();
        if (!this.featureStationDetailsAsync) {
            Station station = stationService.getStationById(trainStop.stationId);
            Log.infof("Found station: %s", station.name);
            trainStop.stationName = station.name; // Note: this line changes behaviour of existing functionality. Don't do this normally
            trainStop.persist();
        } else {
            trainStop.persist();
            stationDetailsProducer.???;
            responseCode = Response.Status.ACCEPTED.getStatusCode();
        }

        return Response.ok(trainStop).status(responseCode).build();
```

#### Step 3: Configure the Messaging Channel

In `application.properties`, configure the outgoing channel to connect to your messaging broker.

```properties
# Configure the outgoing channel for SAGA requests
mp.messaging.outgoing.station-details-requests-out.topic=station-details-requests
mp.messaging.outgoing.station-details-requests-out.connector=smallrye-kafka
```

#### Step 4: Test if it works

Ideally, we have automated tests for this, but let's go ahead and test that create requests produce station-detail-request messages. Start up your lab environment if you haven't already.

Run your train-line-service in dev mode
```sh
quarkus dev
```

Make a request to create a TrainStop
```sh
DATE_TIME_FORMAT="%Y-%m-%dT%H:%M:%SZ"
DATE_TIME=$(date -u +$DATE_TIME_FORMAT)
STATION_ID=$((STATION_ID % 3 + 1))
curl -v \
  -H "Content-Type: application/json" \
  -d '{"stationId": "'${STATION_ID}'", "arrivalTime": "'${DATE_TIME}'"}' \
  "http://${TRAIN_LINE_IP_AND_PORT}/stops"
```

Open the dev-ui and use the `Apache Kafka Client` extension to view the `station-details-request` topic. You should be able to see the message produced for the last TrainStop created.

#### Step 5: Save your work

Commit your changes to Git.
```sh
git add .
git commit -m "feat: Lab 7 in progress: StationDetailsProducer implemented"
```

---

## Part 3: The SAGA Step & Resilience (The Consumer)

### Objective
Implement a message consumer that listens for station detail requests, processes them by calling the `station-service`, and applies resilience patterns.

### Instructions

#### Step 6: Create the Message Consumer

This time we'll start by the test! We want a consumer that, upon reception of the message makes the call to the station-service with our existing RestClient.

Here's what we want to implement the consumer to do upon each message:
 - Acknowledge the message (this could be done automatically)
 - For a message with stationId {s} and TrainStop {t}
  - If the TrainStop {t} doesn't exist Log an error and exit
  - Else send a request to station-service for details of station {s}
    - If the stationDetails request is successful use the stationDetails to update {t}
    - If the stationDetails request is unsuccessful
      - If the error is a 404, station {s} doesn't exist in the database
        - delete {t} from the database
        - Log a corresponding error
      - else station {s} may exist in the database but the request failed
        - Update the TrainStop {t} stationName with "Station details not available"
        - Log a corresponding error

```java
@QuarkusTest
public class StationDetailsConsumerTest {

    // We're going to need to mock the StationService
    ???

    @Inject
    StationDetailsConsumer stationDetailsConsumer;

    @ConfigProperty(name = "feature.toggle.station-details-async")
    boolean stationDetailsAsync;

    @BeforeEach
    @Transactional
    void setup() {
        TrainStop.deleteAll();
    }

    @AfterEach
    void teardown() {
        logHandler.clear();
    }

    @Test
    @Transactional
    void testConsumerSuccess() {
        Assumptions.assumeTrue(stationDetailsAsync, "Station details async feature is disabled");

        // Given
        // The TrainStop with the StationId exists in the database
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();
        trainStop.persist();
        // Station details exist and the station service will succeed
        Station station = new Station();
        station.id = "1";
        station.name = "Station 1";
        station.location = "Location 1";
        Mockito.when(stationService.getStationById("1")).thenReturn(station);

        // When a message is sent
        var stationDetailsRequest = new StationDetailsRequestMessage(???, ???);
        stationDetailsConsumer.processStationDetailsRequest(stationDetailsRequest);

        // Verify that the StationDetailsConsumer processed the message and updated the TrainStop
        TrainStop updatedTrainStop = TrainStop.findById(trainStop.id);
        Assertions.assertEquals(station.name, updatedTrainStop.stationName);
    }

    @Test
    @Transactional
    void testConsumerTrainStopNotFound() {
        Assumptions.assumeTrue(stationDetailsAsync, "Station details async feature is disabled");

        // Given
        // TrainStop does not exist in the database
        Long trainStopId = 1L;
        String stationId = "1"

        // When a message is sent
        var stationDetailsRequest = new StationDetailsRequestMessage(trainStopId, stationId);
        stationDetailsConsumer.processStationDetailsRequest(stationDetailsRequest);

        // Verify that the StationDetailsConsumer error was Logged indicating that the TrainStop was not found
        // Intercepting the logs in this lab has not been done, but you can imagine it here, or if you know how to do it do it! :)
    }

    @Test
    @Transactional
    void testConsumerTrainStopFoundStationNotFound() {
        Assumptions.assumeTrue(stationDetailsAsync, "Station details async feature is disabled");

        // Given
        // The TrainStop with the StationId exists in the database
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();
        trainStop.persist();
        // The station-service does not find the station and returns a 404
        Mockito.when(???).thenThrow(new WebApplicationException("Station not found", 404));

        // When a message is sent
        var stationDetailsRequest = new StationDetailsRequestMessage(trainStop.id, trainStop.stationId);
        stationDetailsConsumer.processStationDetailsRequest(stationDetailsRequest);

        // Verify that the StationDetailsConsumer error was logged indicating that the Station details were not found
        // Verify that the trainStop was removed from the database
        Assertions.assertNull(TrainStop.findById(trainStop.id));
    }

    @Test
    @Transactional
    void testConsumerTrainStopFoundStationRequestFailed() {
        Assumptions.assumeTrue(stationDetailsAsync, "Station details async feature is disabled");

        // Given
        // The TrainStop with the StationId exists in the database
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();
        trainStop.persist();
        var stationDetailsRequest = new StationDetailsRequestMessage(trainStop.id, trainStop.stationId);
        // the station-service request fails with a server error
        Mockito.when(stationService.getStationById("1")).thenThrow(new WebApplicationException("Station request failed", ???));

        // When a message is sent
        stationDetailsConsumer.processStationDetailsRequest(stationDetailsRequest);

        // Verify that the StationDetailsConsumer error was logged indicating that the Station details were not found
        // Verify that the trainStop is updated with an arbitrary value
        TrainStop updatedTrainStop = TrainStop.findById(trainStop.id);
        Assertions.assertEquals("Station details not available", updatedTrainStop.stationName);
    }
}
```

There are probably some syntax errors. So let's create a new class, `StationDetailsConsumer`, to process incoming messages. This class will consume from the `station-details-requests` channel.

```java
@ApplicationScoped
public class StationDetailsConsumer {

    @Inject
    @RestClient
    StationService stationService;

    @Incoming("station-details-requests-in")
    @Transactional
    @Retry(maxRetries = 3, delay = 1000)
    public void processStationDetailsRequest(StationDetailsRequestMessage request) {
        Log.infof("Received station detail request for trainStop: %d, stationId: %s", request.trainStopId(), request.stationId());

        Optional<TrainStop> stopOptional = TrainStop.findByIdOptional(request.trainStopId());
        if (stopOptional.isEmpty()) {
            Log.warnf("No TrainStop with id %d, skipping update.", request.trainStopId());
            return;
        }
        TrainStop stopToUpdate = stopOptional.get();

        try {
            Station station = stationService.getStationById(request.stationId());
            Log.infof("Successfully fetched details for station: %s", station.name);
            // Update the station details (the station.name) and persist
            ???
            ???
        } catch (WebApplicationException e) {
            if(e.getResponse().getStatus() == ???) {
                Log.errorf(e, "StationId %s does not exist. Deleting TrainStop %d", request.stationId(), request.trainStopId());
                // Delete the trainStop
                ???
            } else {
                Log.errorf(e, "Failed to fetch details for station %s. Updating TrainStop with arbitrary station details", request.stationId());
                stopToUpdate.stationName = ???;
                stopToUpdate.persist();
            }
        }
    }
}
```

#### Step 7: Configure the Messaging Channel

```sh
...
mp.messaging.incoming.station-details-requests-in.topic=station-details-requests
mp.messaging.incoming.station-details-requests-in.connector=smallrye-kafka
```

#### Step 8: Test if it works

```sh
quarkus test
```

If all of the tests are passing, deploy your service and test if it works in the lab environment stack.

Use the following curl commands to make create requests and subsequently view the results:

```sh
DATE_TIME=$(date -u +$DATE_TIME_FORMAT)
STATION_ID=$((STATION_ID % 3 + 1))
curl -v \
  -H "Content-Type: application/json" \
  -d '{"stationId": "'${STATION_ID}'", "arrivalTime": "'${DATE_TIME}'"}' \
  "http://${TRAIN_LINE_IP_AND_PORT}/stops"
```

```sh
# Use the id returned in the response of the above request
curl localhost:8080/stops/${id}
```

### Step 9: Save your work

Commit your changes to Git.

```bash
git add .
git commit -m "feat: Lab 7 complete - SAGA Choreography with Reactive Messaging"
```

## Final Check

- [ ] Have you added the neccessary dependencies to your `pom.xml`?
- [ ] Does your `StationDetailsProducer` have an emitter for `station-details-requests`?
- [ ] Does your `TrainStopResource` correctly produce a message to start the SAGA?
- [ ] Does your `StationDetailsConsumer` consume the request, call the `station-service`, and update the `TrainStop` as specified?
- [ ] Are both the request and response channels correctly configured in `application.properties`?
- [ ] Do your tests verify that the `TrainStopResource` sends the initial message?
- [ ] Do your tests for the `StationDetailsConsumer` cover both the success and failure cases, including the deletion of the `TrainStop` on failure?

## Discussion Points

*   **Choreography vs. Orchestration:** We implemented a choreographed SAGA where services react to each other's events. The alternative is orchestration, where a central service (the orchestrator) tells each participant what to do and when. What are the pros and cons? Choreography promotes service autonomy, but the overall workflow can be hard to track. Orchestration makes the workflow explicit but introduces a single point of failure and tighter coupling.
*   **Eventual Consistency:** This SAGA implementation leads to eventual consistency. There's a time window where the `TrainStop` exists in our database without the full station details. How does this impact API clients? What strategies could you use to inform the client that the process is ongoing (e.g., returning a `202 Accepted` status with a link to check the final status)?
*   **Idempotency:** Message brokers like Azure Service Bus offer "at-least-once" delivery. This means a consumer might receive the same message more than once. Why is it critical that our `StationDetailsConsumer` is idempotent? What would happen if our consumer processed the same `stationId` twice? (Hint: `TrainStop.find("stationId", stationId).firstResult()` helps, but what if the second message arrives before the first is fully processed?)
*   **Compensating Transactions:** In our failure case, we delete the `TrainStop`. This is a "compensating transaction"—an action that undoes the initial step. What would a compensating transaction look like if other services had already acted on the initial `TrainStop` creation? This is a major challenge in SAGA patterns.
*   **Dead-Letter Queues (DLQs):** What happens if a message consistently fails processing even after our `@Retry` policy is exhausted? The message might be lost. Most message brokers support a Dead-Letter Queue (DLQ), where poison pills (un-processable messages) are sent for manual inspection and intervention. This is a critical component for production-grade systems.
*   **Observability in Asynchronous Systems:** Tracing a request across multiple services and message queues is difficult. How would you know that a specific `POST /stops` request resulted in a specific `FAIL` message three seconds later? Distributed tracing (e.g., using OpenTelemetry) becomes essential for observability.
*   **Properly testing StationService with WireMock:** Now that we have separated concerns, the StationService retry, timeout, and fallback logic isn't tested. Testing the RestClient can be done with a [MockHTTPServer like WireMock](https://quarkus.io/guides/rest-client#using-a-mock-http-server-for-tests)
