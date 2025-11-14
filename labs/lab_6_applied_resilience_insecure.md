# Lab 6: Applied Resilience

## Objective

In this lab, you will apply resilience patterns to your `train-line-service`. Your goal is to handle the latency and transient failures of the `station-service` by adding `@Timeout` and `@Retry` annotations to your REST client, aiming for a **90% success rate** on your API calls.

## Theme Integration

The `station-service` has known issues: it's slow and sometimes fails. You must ensure these problems don't cascade to your `train-line-service`. You will explore two methods for tuning your resilience settings to meet the success rate objective, discovering the trade-offs of each approach.

## Prerequisites

- You must have your local cluster running. See Step 1 for instructions on launching the quarkus-lab-6 environment.
- The OIDC Security is deactivated for this lab. Make sure your train-line-service code is aligned with the `start_lab_6_insecure` tag of the `train-line-service` solution repository.
- You must have access to `quay.io/blackstrype` repositories in order to pull the `station-service:insecure` image.

## Instructions

### Step 1: Start the quarkus-lab-6 pod

In your terminal use the `./quarkus-microservices-stack/start-lab-6.sh` to deploy the lab environment.

```sh
# Start the lab environment
./quarkus-microservices-stack/start-lab-6.sh
```

Verify that the cluster is running by testing the station-service with a curl command.

```sh
curl http://localhost:8081/stations
```

### Step 2: Observe the Problem

With your `train-line-service` deployed/running in dev mode, use `curl` to call the `create` endpoint of your `TrainStopResource`.

```bash
# Provide the address and port where your train-line-service is running
TRAIN_LINE_IP_AND_PORT='localhost:8080'

# Create new (unique) stops using the following.
STATION_ID=0
DATE_TIME_FORMAT="%Y-%m-%dT%H:%M:%SZ"

# Make a few calls and see what happens
DATE_TIME=$(date -u +$DATE_TIME_FORMAT)
STATION_ID=$((STATION_ID % 3 + 1))
curl -v \
  -H "Content-Type: application/json" \
  -d '{"stationId": "'${STATION_ID}'", "arrivalTime": "'${DATE_TIME}'"}' \
  "http://${TRAIN_LINE_IP_AND_PORT}/stops"
```

You will observe that some `create` requests take a long time to complete, and others will not only take time, but fail outright. This is the behavior we will fix.

If you're curious, you can view the station-service logs to see how the failure is simulated.

```sh
podman logs station-service-lab
```

### Step 3: Add Dependencies

Open your `pom.xml` file and add the following extension:

- `quarkus-smallrye-fault-tolerance`: Implements the MicroProfile Fault Tolerance specification.

```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-smallrye-fault-tolerance</artifactId>
    </dependency>
```

### Step 4: Add Resilience to Meet the Goal

Your objective is to configure `@Timeout` and `@Retry` on the `StationService` REST client interface to achieve a 9 out of 10 success rate for your requests.

There are two ways to tackle this:

1.  **Manual Tuning:** Add the annotations, deploy the service, and manually test with `curl`, adjusting values as you go.
2.  **Automated Testing:** Write a unit test that mocks the unreliable `station-service` to find the right annotation values quickly.

We will explore both paths.

---

## Approach 1: Manual Tuning and Deployment

This approach gives you a feel for how the service behaves in a live environment, but the feedback loop can be slow.

### Step 5: Add @Timeout and @Retry

In your `StationService.java` interface, add the `@Timeout` and `@Retry` annotations to the `getStationById` method. Start with some initial values that you think are reasonable.

```java
    // Fill in the missing parameters (???)
    final int getStationMaxRetries = ???;
    final int getStationTimeoutMillis = ???;

    ...

    @GET
    @Path("/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    @Timeout(getStationTimeoutMillis)
    @Retry(maxRetries = getStationMaxRetries, maxDuration = getStationTimeoutMillis, delay = 1000)
    Station getStationById(@PathParam("id") String id);
```

### Step 5: Build, Deploy, and Test

Run your updated service.

```bash
quarkus dev
```

Now, run a loop of `curl` commands to test your success rate.

```bash
SUCCESS_COUNT=0
FAILURE_COUNT=0
TOTAL_REQUESTS=10

for (( i=1; i<=$TOTAL_REQUESTS; i++ ))
do
  DATE_TIME=$(date -u +$DATE_TIME_FORMAT)
  STATION_ID=$(( (i % 3) + 1 ))
  echo "Making request $i for stationId: $STATION_ID at $DATE_TIME"
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d '{"stationId": "'${STATION_ID}'", "arrivalTime": "'${DATE_TIME}'"}' \
    "http://${TRAIN_LINE_IP_AND_PORT}/stops")

  if [ "$RESPONSE" -eq 201 ]; then
    echo "Request $i Succeeded (201 Created)"
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
  else
    echo "Request $i Failed (HTTP Status: $RESPONSE)"
    FAILURE_COUNT=$((FAILURE_COUNT+1))
  fi
done

echo "--- Test Summary ---"
echo "Total Requests: $TOTAL_REQUESTS"
echo "Successful Requests: $SUCCESS_COUNT"
echo "Failed Requests: $FAILURE_COUNT"
SUCCESS_RATE=$(echo "scale=2; ($SUCCESS_COUNT * 100) / $TOTAL_REQUESTS" | bc)
echo "Success Rate: $SUCCESS_RATE%"
```

Did you achieve the 90% success rate? You will likely need to adjust the `timeout` and `maxRetries` values, redeploy, and test again. This cycle can be time-consuming.

---

## Approach 2: Automated Testing with Mocks

This is the pragmatic craftsman's approach. Writing a test allows you to simulate the unreliable behavior and validate your resilience settings quickly.

### Step 6: Add Mockito Dependency

Add the `quarkus-junit5-mockito` dependency to your `pom.xml` if it's not already there.

```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-junit5-mockito</artifactId>
        <scope>test</scope>
    </dependency>
```

### Step 7: Create a Mock Test

Create a new test file for your resiliency testing of the `TrainStopResource`. Inject a mock of the `StationService`.

```java
package com.example;

// imports
...

@QuarkusTest
public class TrainStopResourceResilienceTest {

    @Inject
    TrainStopResource trainStopResource;

    @InjectMock
    @RestClient
    StationService stationService;

}
```

### Step 8: Configure the Mock

Now, configure the mock to simulate the behavior of the unreliable `station-service`. You can make it throw exceptions or introduce delays to mimic latency.

```java
...

    @Test
    void testRetryPolicy_SucceedsOnThirdAttempt() {
        // Given: Program the mock's behavior for consecutive calls
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();

        Station mockStation = new Station();
        mockStation.id = "1";
        mockStation.name = "Success Station";

        Mockito.when(stationService.getStationById(Mockito.anyString()))
                .thenThrow(new WebApplicationException("First failure", 500))
                .thenThrow(new WebApplicationException("Second failure", 500))
                .thenReturn(mockStation);

        // When: Call the real service logic that uses the mock
        Response result = trainStopResource.create(trainStop);

        // Then: Verify we got the successful result after retries
        Assertions.assertNotNull(result);
        Assertions.assertEquals("1", ((TrainStop) result.getEntity()).stationId);

        // Also verify the mock was called exactly 3 times
        Mockito.verify(stationService, Mockito.times(3)).getStationById("1");
    }

    @Test
    void testCreateStop_WhenStationServiceIsSlow_ThrowsTimeoutException() {
        // Given: Program the mock to simulate a 3-second delay.
        // This should be intentionally longer than the @Timeout(???) on the client method.
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();

        Station mockStation = new Station();
        mockStation.id = "1";
        mockStation.name = "Success Station";

        Mockito.doAnswer(invocation -> {
            Thread.sleep(???);
            // This return is never reached because the timeout will interrupt it.
            return mockStation;
        }).when(stationService).getStationById(Mockito.anyString());

        // When/Then:
        // We now call our real service logic. We expect this call to fail
        // with a TimeoutException because its dependency (the mock) is too slow.
        Assertions.assertThrows(???, () -> {
            trainStopResource.create(trainStop);
        });

        // Confirm that our mock was indeed called exactly one time before it timed out.
        Mockito.verify(stationService, Mockito.times(1)).getStationById("1");
    }
    
    @Test
    void testCreateStop_WhenStationServiceIsSlowAndFailureProne_SucceedsOnThirdAttempt() {
        // Given: Program the mock's behavior for consecutive calls
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();

        Station mockStation = new Station();
        mockStation.id = "1";
        mockStation.name = "Success Station";

        Mockito.when(stationService.getStationById(Mockito.anyString()))
                .thenAnswer(invocation -> {
                    Thread.sleep(???); // Simulate delay without causing a timeout
                    throw new WebApplicationException("First failure", 500);
                })
                .thenAnswer(invocation -> {
                    Thread.sleep(???);
                    throw new WebApplicationException("Second failure", 500);
                })
                .thenAnswer(invocation -> {
                    Thread.sleep(???);
                    return ???;
                });

        // When: Call the real service logic that uses the mock
        Response result = trainStopResource.create(trainStop);

        // Then: Verify we got the successful result after retries and latencies
        Assertions.assertNotNull(result);
        Assertions.assertEquals("1", ((TrainStop) result.getEntity()).stationId);

        // Also verify the mock was called exactly 3 times
        ???
    }
```

### Step 9: Run the Test

Run your test. It will tell you if your `@Timeout` and `@Retry` values are sufficient to handle the simulated failures. You can adjust the annotations and re-run the test in seconds until you find the right combination.

---

## Final Verification

### Step 10: Deploy and Verify

Once your mock tests pass and you are confident in your resilience settings, build and deploy your service in the local stack. Run the same `curl` loop from Step 5 to confirm the behavior in a live environment.

You will likely notice that achieving a 90% success rate requires a high retry count and a generous timeout.

---

## Part 2: Circuit Breaker

Now that you have `Timeout` and `Retry` implemented, you will add a `CircuitBreaker`. This prevents your service from repeatedly calling a dependency that is clearly failing, which saves resources and allows the failing service time to recover.

### Objective

Add a `@CircuitBreaker` to the `StationService.getStationById` method with the following behavior:

*   If **6 out of the last 10** requests fail, **open the circuit**.
*   While the circuit is open, block new calls for **10 seconds** (fail-fast).
*   After the delay, if **2 consecutive** requests succeed, **close the circuit**.

### Instructions

#### Step 11: Add @CircuitBreaker

Add the `@CircuitBreaker` annotation to the `getStationById` method in your `StationService.java` interface, alongside the existing `@Timeout` and `@Retry` annotations.

```java
    @Retry(maxRetries = getStationMaxRetries, maxDuration = 5000, delay = 1000)
    @CircuitBreaker(
            requestVolumeThreshold = ???, // Consider the last n requests
            failureRatio = ???,           // If 60% fail...
            delay = ???,                  // ...open the circuit for a while
            successThreshold = ???        // Close circuit after 2 consecutive successes
    )
    Station getStationById(@PathParam("id") String id);
```

#### Step 12: Test the Circuit Breaker

This is where testing with mocks shines. It would be very difficult and time-consuming to test this manually.

Write a new test to verify the circuit breaker's behavior. You will need to:

1.  Simulate a series of failures to trigger the circuit to open.
2.  Verify that subsequent calls fail immediately (`CircuitBreakerOpenException`).
3.  Wait for the configured delay.
4.  Simulate successful calls to verify the circuit closes.

```java

    @Test
    void testCircuitBreaker_OpenAfterConsecutiveFailures() {
        // Given: Program the mock to fail consecutively
        // In order to open the circuit, simulate 6 failed requests out of 10
        // To make things interesting let's have the 3 requests succeed after 2 failures each
        // Leave tenth call as a failure and a final success (that will not be called)
        Mockito.when(stationService.getStationById(Mockito.anyString()))
                ??? // 1st failure
                ??? // 2nd failure
                ??? // 1st success
                ???
                ???
                ???
                ???
                ???
                ???
                ???
                .thenThrow(new WebApplicationException("Failure", 500))
                .thenReturn(new Station()); // This should not be called if circuit is open

        // When - The first calls with 2 retries each should succeed, but will open the circuit
        int i;
        for(i = 0; i < 3; i++) {
            TrainStop trainStop = new TrainStop();
            trainStop.stationId = i + "";
            trainStop.arrivalTime = Instant.now();
            Response result = trainStopResource.create(trainStop);
            Assertions.assertNotNull(result);
            Assertions.assertEquals(i + "", ((TrainStop) result.getEntity()).stationId);
        }
        // When and Then - Subsequent calls should immediately fail with CircuitBreakerOpenException
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = i + "";
        trainStop.arrivalTime = Instant.now();
        Assertions.assertThrows(???, () -> ???);
        Assertions.assertThrows(???, () -> ???);

        // Verify that the stationService.getStationById was called 10 times before the circuit was opened
        Mockito.verify(???, Mockito.times(???)).???(Mockito.anyString());
    }
```

#### Step 13: Reset the circuit for other tests

You may have noticed that the open circuit is impacting your other tests. Add a cleanup after each test to ensure that the circuit breaker reset. We'll use the `CircuitBreakerMaintenance`.

```java
    @Inject
    CircuitBreakerMaintenance circuitBreakerMaintenance;

    ...

    @AfterEach
    public void resetCircuitBreaker() {
        circuitBreakerMaintenance.resetAll();
    }
```

#### Step 14: Deploy and Observe (Optional)

With all your mock tests passing, you have high confidence in your resilience configuration. If you wish, deploy the `train-line-service` to AKS and use `curl` to observe the behavior. It will be hard to see the circuit breaker in action without putting the `station-service` under significant, specific stress, which is why mock testing is so valuable.

---

## Part 3: Fallback

Now we notice that, despite our retries, our `train-line-service` is still exposing exceptions in the API responses. To alleviate this, we'll implement a `@Fallback` to provide a sub-optimal, but clean response.

### Objective

Implement and test the `@Fallback` on the `StationService.getStationById` to return a stub `Station` object.

The tests will need to show that when requests to the `station-service` fail, the `TrainStopResource.create()` nonetheless returns a 201.

### Step 15: Introduce the Fallback

Add the `@Fallback` annotation to the `getStationById` method in your `StationServiceClient` interface. You also need to implement the static fallback method itself directly in the interface.

```java
    @Fallback(fallbackMethod = "???")
    Station getStationById(@PathParam("id") String id);

    static Station getStationByIdFallback(String id) {
        Station fallback = new Station();
        fallback.id = "0";
        fallback.name = "Station Details Currently Unavailable";
        return fallback;
    }
```

### Step 16: Write the Fallback test

```java
@Test
    void testFallback_ProvidesDefaultWhenRequestFails() {
        // Given: Program the mock to fail consecutively to open the circuit breaker
        Mockito.when(stationService.getStationById(Mockito.anyString()))
                ???
                ???
                ???;
        
        // When: StationService station details are requested and the three retries fail
        TrainStop trainStop = new TrainStop();
        trainStop.stationId = "1";
        trainStop.arrivalTime = Instant.now();
        // This call will trigger the max retry failure and a fallback Station should be provided
        Response result = ???;

        // Then: The fallback station should be provided and prevent exceptions
        Assertions.assertNotNull(result);
        Assertions.assertEquals(???.getStatusCode(), result.getStatus());
        TrainStop createdTrainStop = (TrainStop) result.getEntity();
        Assertions.assertEquals("1", createdTrainStop.stationId);

        // Verify that stationService was called enough times to trigger a fallback
        Mockito.verify(stationService, Mockito.times(4)).getStationById(Mockito.anyString());
    }
```

### Step 17: Update existing tests

 The previously written tests will now need to be updated to accomodate the fallback instead of the various exceptions that were previously thrown. Correct the existing tests.

 ### Step 18: Tear down the lab environment

 Run quarkus-microservice-stack/stop-lab-6.sh to bring down the lab environment.

 ```sh
 ./quarkus-microservices-stack/stop-lab-6.sh
 ```

 Make sure the quarkus-lab-6 pod is no longer running with a check for running pods.

 ```sh
 podman ps
 ```

 ### Step 19: Save your work

Commit your changes to Git.

```bash
git add .
git commit -m "feat: Lab 6 complete - Applied Resilience with Retry, Timeout, CircuitBreaker, and Fallback"
```

## Final Check

- [ ] Have you added the necessary dependencies?
- [ ] Did you successfully use `@Timeout` and `@Retry` to achieve the 90% success rate?
- [ ] Did you try both the manual and automated testing approaches?
- [ ] Have you implemented the `@CircuitBreaker` with the specified parameters?
- [ ] Do your mock tests verify that the circuit opens and closes correctly?
- [ ] Have you implemented `@Fallback` and tested that it?
- [ ] Have you considered the implications for the SLA of `station-service` and/or `train-line-service`?

## Discussion Points

*   **Which approach was more efficient?** Why is a fast feedback loop crucial for software craftsmanship? How does Quarkus make automated testing easier ? [Smallrye Fault Tolerence Guide](https://quarkus.io/guides/smallrye-fault-tolerance)
*   **Service Level Agreements (SLAs):** The high retry count and timeout needed to stabilize the interaction highlight a problem with the `station-service`. Client-side resilience can only do so much. This situation should lead to a conversation about the SLA with the `station-service` team. Is their service reliable enough?
*   **Limitations of Resilience:** Resilience patterns are for handling *transient* failures (network outages, intermittent latencies), not for fixing fundamental problems in a downstream service.
*   **Fail Fast:** How does the Circuit Breaker help both the `train-line-service` (the client) and the `station-service` (the dependency)?
*   **SmallRye Fault Tolerance:** More information on the implementation of resilience in Quarkus and the different resilience patterns available: [SmallRye Fault Tolerance Documentation](https://smallrye.io/docs/smallrye-fault-tolerance/6.9.3/index.html)
