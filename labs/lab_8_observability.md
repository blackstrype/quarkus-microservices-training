# Lab 8: Observability

## Objective

Learn how to establish simple and effective monitoring for your service with SmallRye Health and SmallRye Metrics.

## Theme Integration

Now that we have a pretty well-established service, we want to start tracking it's performance and general operation. Add base metrics to the train-line-service to ensure it is operational. Also track some key metrics like, how long it is taking to fetch station details, and how many times the station details requests are failing.

## Prerequisites

- A running instance of a kafka messaging broker
- Your Quarkus project from the end of Lab 7 (tag solution_lab_7_insecure).
- You have configured your `application.properties` with the connection details for your messaging broker.
- You have started up your local stack (run `./quarkus-microservices-stack/start-lab-8.)

---

## Part 1: The Path of Least Resistence Using Default Health Checks and Metrics

### Objective
Add the default Health check to your service and prepare for using MicroProfile Metric annotations

### Instructions

#### Step 1: Add Dependencies

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-health</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-metrics</artifactId>
</dependency>
```

#### Step 2: Run it!

Run the application with `quarkus dev`, request the health status of your application:

```sh
TRAIN_LINE_IP_AND_PORT=localhost:8080
curl $TRAIN_LINE_IP_AND_PORT/q/health
```

As you can see there are already some basic checks verifying the dependencies of the app:
- The postgres database connection
- The message broker connection for each of the connectors

There are three types of checks for the Reactive Messaging connectors:
- Liveness: The connection to the message bus is confirmed
- Readiness: Not only is the connection established, but the connector is ready to start producing and consuming messages
- Startup Check: The connector finished startup (at the initial boot of the connector/application).

### Part 2: Some Base and Application Metrics

#### Step 1: Observe the Base Metrics
Take a moment to observe the metrics
```
TRAIN_LINE_IP_AND_PORT=localhost:8080
curl $TRAIN_LINE_IP_AND_PORT/q/metrics
```

Already you can see there a generous amount of base metrics which are automatically collected. These can be often scraped directly and used by operation teams to monitor the health of your instances.

#### Step 2: Programmatically add a few key metrics
First off, add a @Timed metric on the StationDetailsConsumer.processStationDetailsRequest() to see how long it is taking to process station detail requests. The annotation by default is generated based on the name of the method being annotated (something like `application_process_station_details_request_seconds`). You can also cusomize the name of the metric as shown below 

```java
    @Timed("process-station-details")
    public void processStationDetailsRequest(StationDetailsRequestMessage request) {
```

Second, Add @Counted metric on StationFallbackHandler.handle to see how often our fallback handler is being used when using the StationService RestClient. To make it easy to find in the returned metrics we'll give it a custom name again.

```java
    @Counted("station-fallback-handler")
    public Station handle(ExecutionContext context) {
```

Make a call to the metrics endpoint and search for the `station-fallback-handler` and `process-station-details` metrics
```
TRAIN_LINE_IP_AND_PORT=localhost:8080
curl $TRAIN_LINE_IP_AND_PORT/q/metrics
```

### Part 3: Collecting and Viewing the Metrics

#### Step 1: LGTM (Loki, Grafana, Tempo, Mimir)

Add the dependencies for the LGTM Dev Services module
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-observability-devservices-lgtm</artifactId>
    <scope>provided</scope>
</dependency>
```

We're going to use Quarkus' OpenTelemetry extension to scrape metrics and provide them to Grafana. And because we are creating a few Micrometer-annotated metrics, we'll add the micrometer-opentelemetry bridge to make sure we collect the micrometer metrics.
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-micrometer-opentelemetry</artifactId>
</dependency>
```

Note: There may be some dependency collisions here with the quarkus-smallrye-metrics extension. If you notice errors during your dev startup, remove the extension
```sh
quarkus extension rm micrometer-opentelemetry
```

Start up your app in dev mode. Then Let's generate some traffic. The following will send out 1 requests every 5 seconds.
```sh
TRAIN_LINE_IP_AND_PORT='localhost:8080'
SUCCESS_COUNT=0
FAILURE_COUNT=0
TOTAL_REQUESTS=100
STATION_ID=0
DATE_TIME_FORMAT="%Y-%m-%dT%H:%M:%SZ"
SLEEP_TIME_SEC=5

for (( i=1; i<=$TOTAL_REQUESTS; i++ ))
do
  DATE_TIME=$(date -u +$DATE_TIME_FORMAT)
  STATION_ID=$(( (i % 3) + 1 ))
  echo "Making request $i for stationId: $STATION_ID at $DATE_TIME"
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d '{"stationId": "'${STATION_ID}'", "arrivalTime": "'${DATE_TIME}'"}' \
    "http://${TRAIN_LINE_IP_AND_PORT}/stops")
  sleep $SLEEP_TIME_SEC
done
```

Open the dev services console (If you have your app runnig in the console, press `d` to open the console in the browser).
Search for the Observability extension and navigate to the Grafana console provided by the link (Extentensions -> Observability -> Grafana UI).
  (You can also look in Dev Services -> observability -> grafana.endpoint in order to have the ephemeral url where the grafana UI is deployed)

Once in the Grafana UI, first stop is to see the Micrometer OpenTelemetry Bridge Dashboard (Dashboards -> Quarkus Micrometer OpenTelemetry). Here you can get many of the Base Metrics that we were requesting via the `/q/metrics` endpoint.

Next, go into (Drilldown -> Metrics -> Let's Start!). In the 'Search Metrics' bar, search for "station". You should be able to see our customly tagged metrics.
Grafana is a powerful monitoring tool. You can set up some elaborate dashboards and store them.

#### Step 2: Add Logging

The logging Dashboard does not yet show any logs. Simply enable OTEL logging and visit Dashboards -> Quarkus OpenTelemetry Logging.

```properties
quarkus.otel.logs.enabled=true
```

Generate some of the previous traffic to have some logs collected.
Logging can be and should be customized. Find more information here: [Quarkus Open Telemetry Logging](https://quarkus.io/guides/opentelemetry-logging)

### Part 4: Save your work

Commit your changes to Git.

```bash
git add .
git commit -m "feat: Lab 8 complete - Health and Metrics"
```

## Final Check

- [ ] Does your service have some basic health checks ? 
- [ ] Does your service have base metrics available ?
- [ ] Are you able to collect metrics for your station-details requests using `@Counted` and `@Timed`?
- [ ] Were you able to launch Grafana with OpenTelemetry ?
- [ ] Were you able to quickly active OTEL Logging ?

## Discussion Points

*   **Example Discussion Point:** Here's a small discussion point for going further on the lab we just did. Here is a link to find [more information](https://example.org/discussion-point).
*   **Microprofile Health Specification:** As usual, the Microprofile Health Specification is very readable. [Microprofile Health v4.0.1](https://download.eclipse.org/microprofile/microprofile-health-4.0.1/microprofile-health-spec-4.0.1.html).
*   **Quarkus' Overview of Observability:** [Observability in Quarkus](https://quarkus.io/guides/observability)
*   **Quarkus LGTM Dev Services:** [Quarkus Guide on the LGTM Observability Stack](https://quarkus.io/guides/observability-devservices-lgtm)
