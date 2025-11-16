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

Modify the `TrainStopResourceTest` so that create calls receive a 202 instead of a 201.

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
        """).when().post("/stops").then()
                .statusCode(expectedCreateStatusCode)
                .body("stationId", is("station-2"));
```

Run the tests with the async station details feature toggle disabled. The tests should pass.

```sh
quarkus test -D=feature.toggle.station-details-async=false
```

Now, run the test with the feature toggle enabled (already `true` your config). The tests should fail.

```sh
quarkus test
```

#### Step 2: Make the Async Tests Pass

Modify the TrainStopResource create method. In order to avoid breaking the current functionality, wrap the existing call in a conditional that will implement async call when the feature is toggled, otherwise the existing implementation.
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

Update the StationService interface to use the StationFallbackHandler.
```java
    ...
    @Fallback(StationFallbackHandler.class)
    Station getStationById(@PathParam("id") String id);
    ...
}
```

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
    @Schema(description = "The name of the station", example = "Central Station")
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
DATE_TIME=$(date -u +$DATE_TIME_FORMAT)
STATION_ID=$((STATION_ID % 3 + 1))
curl -v \
  -H "Content-Type: application/json" \
  -d '{"stationId": "'${STATION_ID}'", "arrivalTime": "'${DATE_TIME}'"}' \
  "http://${TRAIN_LINE_IP_AND_PORT}/stops"
```

Open the dev-ui and use the `Apache Kafka Client` extension to view the `station-details-request` topic. You should be able to see the message produced for the last TrainStop created.

---

## Part 3: The SAGA Step & Resilience (The Consumer)

### Objective
Implement a message consumer that listens for station detail requests, processes them by calling the `station-service`, and applies resilience patterns.

### Instructions

#### Step 6: Create the Message Consumer

Create a new class, `StationDetailsConsumer`, to process incoming messages. This class will consume from the `station-details-requests` channel.

```java
package com.example;

import org.eclipse.microprofile.reactive.messaging.Incoming;
import jakarta.enterprise.context.ApplicationScoped;
// Other imports...

@ApplicationScoped
public class StationDetailsConsumer {

    @Inject
    @RestClient
    StationService stationService;

    @Incoming("station-details-requests")
    @Transactional
    @Retry(maxRetries = 3, delay = 1000)
    public void processStationDetailsRequest(String stationId) {
        Log.infof("Received station detail request for stationId: %s", stationId);

        TrainStop stopToUpdate = TrainStop.find("stationId", stationId).firstResult();
        if (stopToUpdate == null) {
            Log.warnf("No TrainStop found for stationId %s, skipping update.", stationId);
            return;
        }

        try {
            Station station = stationService.getStationById(stationId);
            // In a real SAGA, you'd update the TrainStop with details from the station
            // For now, we just log it.
            Log.infof("Successfully fetched details for station: %s", station.name);
            // stopToUpdate.stationName = station.name;
            // stopToUpdate.persist();
        } catch (WebApplicationException e) {
            Log.errorf(e, "Failed to fetch details for station %s. Removing associated TrainStop.", stationId);
            stopToUpdate.delete();
        }
    }
}
```

#### Step 7: Write Tests for the Consumer

Write tests to verify the consumer's logic for both success and failure scenarios.

```java
@QuarkusTest
public class StationDetailsConsumerTest {

    @InjectMock
    @RestClient
    StationService stationService;

    @Inject
    @Channel("station-details-requests")
    InMemoryConnector connector;

    @Test
    @Transactional
    void testConsumerSuccess() {
        // Given a TrainStop exists and the station service will succeed
        TrainStop.deleteAll();
        new TrainStop("1", Instant.now()).persist();
        Mockito.when(stationService.getStationById("1")).thenReturn(new Station("1", "Success Station"));

        // When a message is sent
        InMemorySource<String> requests = connector.source("station-details-requests");
        requests.send("1");

        // Then the TrainStop should still exist (and would be updated in a real scenario)
        Assertions.assertEquals(1, TrainStop.count());
    }

    @Test
    @Transactional
    void testConsumerFailure() {
        // Given a TrainStop exists and the station service will fail
        TrainStop.deleteAll();
        new TrainStop("2", Instant.now()).persist();
        Mockito.when(stationService.getStationById("2")).thenThrow(new WebApplicationException(404));

        // When a message is sent
        InMemorySource<String> requests = connector.source("station-details-requests");
        requests.send("2");

        // Then the TrainStop should be deleted
        Assertions.assertEquals(0, TrainStop.count());
    }
}
```

#### Step 8: Refactor the `TrainStopResource`

Now that the consumer handles fetching station details, remove the synchronous call to `stationService` from the `create` method in `TrainStopResource`.

```java
// In TrainStopResource.java, inside create() method
// REMOVE THIS LINE:
// Station station = stationService.getStationById(trainStop.stationId);
```

## Part 3: The Choreography Completing the SAGA

### Objective
Connect the SAGA steps by having the consumer produce a subsequent event upon completion. This closes the loop on the asynchronous operation, making the system's state transparent and enabling further workflow steps.

### Action
Upon successful processing, the consumer will send a `SUCCESS` message to a `station-details-response` channel. If the `TrainStop` is removed (due to the `station-service` call failing), it will produce a `FAIL` message with details. We will add tests to verify that the correct messages appear on the response channel for both `SUCCESS` and `FAIL` cases.

### Choreography
This approach, where services communicate directly with each other via events without a central controller, is known as **Choreography**. It promotes loose coupling and high autonomy among services.

---

### Instructions

#### Step 9: Create a Response Message DTO

To standardize the response format, create a simple `StationDetailResponse` record.

```java
package com.example;

public record StationDetailResponse(String status, String details, String stationId) {
    public static StationDetailResponse success(String stationId) {
        return new StationDetailResponse("SUCCESS", "Station details processed successfully.", stationId);
    }

    public static StationDetailResponse failure(String stationId, String reason) {
        return new StationDetailResponse("FAIL", reason, stationId);
    }
}
```

#### Step 10: Update the `StationDetailsProducer`

Add a new `Emitter` to your `StationDetailsProducer` to send the response message. You'll also need the `quarkus-jsonb` dependency if it's not already in your `pom.xml`.

```xml
<!-- Add if not present -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jsonb</artifactId>
</dependency>
```

```java
// In StationDetailsProducer.java
import org.eclipse.microprofile.reactive.messaging.Message;
// ...

@Inject
@Channel("station-details-response")
Emitter<StationDetailResponse> stationDetailsResponseEmitter;

public void sendStationDetailsResponse(StationDetailResponse response) {
    stationDetailsResponseEmitter.send(response);
}
```

#### Step 11: Update the `StationDetailsConsumer` to Produce Responses

Inject the `StationDetailsProducer` into the `StationDetailsConsumer` and modify the logic to send a response message after processing is complete.

```java
// In StationDetailsConsumer.java
@Inject
StationDetailsProducer StationDetailsProducer;

// ... inside processStationDetailsRequest method

try {
    Station station = stationService.getStationById(stationId);
    Log.infof("Successfully fetched details for station: %s", station.name);
    // In a real SAGA, you'd update the TrainStop
    // stopToUpdate.stationName = station.name;
    // stopToUpdate.persist();
    
    // Send SUCCESS response
    StationDetailsProducer.sendStationDetailsResponse(StationDetailResponse.success(stationId));

} catch (WebApplicationException e) {
    Log.errorf(e, "Failed to fetch details for station %s. Removing associated TrainStop.", stationId);
    stopToUpdate.delete();

    // Send FAIL response
    String reason = "Failed to fetch station details, received status: " + e.getResponse().getStatus();
    StationDetailsProducer.sendStationDetailsResponse(StationDetailResponse.failure(stationId, reason));
}
```

#### Step 12: Configure the Response Channel

In `application.properties`, configure the new outgoing channel for responses.

```properties
# Configure the outgoing channel for SAGA responses
mp.messaging.outgoing.station-details-response.connector=smallrye-amqp
mp.messaging.outgoing.station-details-response.address=station-details-response-queue
```

#### Step 13: Write Tests for the Response Messages

Create a new test file or add to an existing one to verify that the consumer produces the correct `SUCCESS` and `FAIL` messages.

```java
@QuarkusTest
public class StationDetailsResponseTest {

    @InjectMock
    @RestClient
    StationService stationService;

    @Inject
    @Channel("station-details-requests")
    InMemoryConnector requestsConnector;

    @Inject
    @Channel("station-details-response")
    InMemoryConnector responsesConnector;

    @BeforeEach
    @Transactional
    void setup() {
        TrainStop.deleteAll();
        responsesConnector.sink("station-details-response").clear();
    }

    @Test
    @Transactional
    void testConsumerSendsSuccessResponse() {
        // Given a TrainStop exists and the station service will succeed
        new TrainStop("1", Instant.now()).persist();
        Mockito.when(stationService.getStationById("1")).thenReturn(new Station("1", "Success Station"));
        InMemorySource<String> requests = requestsConnector.source("station-details-requests");
        InMemorySink<StationDetailResponse> responses = responsesConnector.sink("station-details-response");

        // When a message is sent to the request channel
        requests.send("1");

        // Then a SUCCESS message should be sent to the response channel
        Assertions.assertEquals(1, responses.received().size());
        StationDetailResponse response = responses.received().get(0).getPayload();
        Assertions.assertEquals("SUCCESS", response.status());
        Assertions.assertEquals("1", response.stationId());
    }

    @Test
    @Transactional
    void testConsumerSendsFailResponse() {
        // Given a TrainStop exists and the station service will fail
        new TrainStop("2", Instant.now()).persist();
        Mockito.when(stationService.getStationById("2")).thenThrow(new WebApplicationException(404));
        InMemorySource<String> requests = requestsConnector.source("station-details-requests");
        InMemorySink<StationDetailResponse> responses = responsesConnector.sink("station-details-response");

        // When a message is sent to the request channel
        requests.send("2");

        // Then a FAIL message should be sent to the response channel
        Assertions.assertEquals(1, responses.received().size());
        StationDetailResponse response = responses.received().get(0).getPayload();
        Assertions.assertEquals("FAIL", response.status());
        Assertions.assertEquals("2", response.stationId());
        Assertions.assertTrue(response.details().contains("404"));
    }
}
```

### Step 14: Save your work

Commit your changes to Git.

```bash
git add .
git commit -m "feat: Lab 7 complete - SAGA Choreography with Reactive Messaging"
```

## Final Check

- [ ] Have you added the `quarkus-smallrye-reactive-messaging-amqp` and `quarkus-jsonb` dependencies to your `pom.xml`?
- [ ] Does your `StationDetailsProducer` have emitters for both `station-details-requests` and `station-details-response`?
- [ ] Does your `TrainStopResource` correctly produce a message to start the SAGA?
- [ ] Does your `StationDetailsConsumer` consume the request, call the `station-service`, and produce a `SUCCESS` or `FAIL` response message?
- [ ] Are both the request and response channels correctly configured in `application.properties`?
- [ ] Do your tests verify that the `TrainStopResource` sends the initial message?
- [ ] Do your tests for the `StationDetailsConsumer` cover both the success and failure cases, including the deletion of the `TrainStop` on failure?
- [ ] Do your final tests confirm that the correct `SUCCESS` and `FAIL` `StationDetailResponse` messages are sent to the response channel?

## Discussion Points

*   **Choreography vs. Orchestration:** We implemented a choreographed SAGA where services react to each other's events. The alternative is orchestration, where a central service (the orchestrator) tells each participant what to do and when. What are the pros and cons? Choreography promotes service autonomy, but the overall workflow can be hard to track. Orchestration makes the workflow explicit but introduces a single point of failure and tighter coupling.
*   **Eventual Consistency:** This SAGA implementation leads to eventual consistency. There's a time window where the `TrainStop` exists in our database without the full station details. How does this impact API clients? What strategies could you use to inform the client that the process is ongoing (e.g., returning a `202 Accepted` status with a link to check the final status)?
*   **Idempotency:** Message brokers like Azure Service Bus offer "at-least-once" delivery. This means a consumer might receive the same message more than once. Why is it critical that our `StationDetailsConsumer` is idempotent? What would happen if our consumer processed the same `stationId` twice? (Hint: `TrainStop.find("stationId", stationId).firstResult()` helps, but what if the second message arrives before the first is fully processed?)
*   **Compensating Transactions:** In our failure case, we delete the `TrainStop`. This is a "compensating transaction"—an action that undoes the initial step. What would a compensating transaction look like if other services had already acted on the initial `TrainStop` creation? This is a major challenge in SAGA patterns.
*   **Dead-Letter Queues (DLQs):** What happens if a message consistently fails processing even after our `@Retry` policy is exhausted? The message might be lost. Most message brokers support a Dead-Letter Queue (DLQ), where poison pills (un-processable messages) are sent for manual inspection and intervention. This is a critical component for production-grade systems.
*   **Observability in Asynchronous Systems:** Tracing a request across multiple services and message queues is difficult. How would you know that a specific `POST /stops` request resulted in a specific `FAIL` message three seconds later? Distributed tracing (e.g., using OpenTelemetry) becomes essential for observability.
*   **Properly testing StationService with WireMock:** Now that we have separated concerns, the StationService retry, timeout, and fallback logic isn't tested. Testing the RestClient can be done with a [MockHTTPServer like WireMock](https://quarkus.io/guides/rest-client#using-a-mock-http-server-for-tests)
