# Lab 2: Dynamic Configuration & Deployment

## Objective

In this lab, you will configure your microservice to be environment-agnostic using dynamic configuration. You will then containerize and deploy your application to a local Kubernetes cluster, which is a key objective of the training.

## Theme Integration

As a key component of the Smart City Transit Network, your `train-line-service` needs to be flexible and deployable. In this lab, we will configure the service with a unique `train-line-name` and deploy it to the Kubernetes cluster.

## Instructions

1.  **Debugging and Logging in Dev Mode**

    Introduce the `Logger`. Open `StatusResource.java` and inject a logger.

    ```java
    // src/main/java/com/example/StatusResource.java
    package com.example;

    import jakarta.ws.rs.GET;
    import jakarta.ws.rs.Path;
    import jakarta.ws.rs.Produces;
    import jakarta.ws.rs.core.MediaType;
    import org.jboss.logging.Logger;

    @Path("/status")
    public class StatusResource {

        private static final Logger logger = Logger.getLogger(StatusResource.class);

        @GET
        @Produces(MediaType.TEXT_PLAIN)
        public String status() {
            logger.info("Checking the status of the train line service...");
            return "Operational";
        }
    }
    ```

    **Run with the Debugger Attached**: Start the application in dev mode and attach your debugger to port `5005`.

    ```bash
    ./mvnw quarkus:dev
    ```

    Set a breakpoint on the `return "Operational";` line in `status()` and refresh the browser at `http://localhost:8080/status`. Observe the debugger stopping at the breakpoint.

    **Demonstrate Live Reload**: While the debugger is attached, modify the log message and observe the application recompile instantly without losing the debugger connection.
    - Change the log message to `logger.info("Status check successful.");`.
    - Change the return statement to `return "Running smoothly";`.
    - Refresh the browser and observe the new behavior.

2.  **Dynamic Configuration**

    Introduce the `@ConfigProperty` annotation. Open `StatusResource.java` and inject a new property.

    ```java
    // src/main/java/com/example/StatusResource.java
    // ...
    import org.eclipse.microprofile.config.inject.ConfigProperty;

    // ...
    @Path("/status")
    public class StatusResource {

        private static final Logger logger = Logger.getLogger(StatusResource.class);

        @ConfigProperty(name = "train-line-name")
        String trainLineName;

        @GET
        @Produces(MediaType.TEXT_PLAIN)
        public String status() {
            logger.info("Status check successful for " + trainLineName);
            return "Operational";
        }
    }
    ```

    Define the property. Create a new `application.properties` file in `src/main/resources` and add the following line.

    ```properties
    # src/main/resources/application.properties
    train-line-name=Express-Line-A
    ```

    Observe the changes. Refresh the browser at `http://localhost:8080/status` and observe the new log message with the `train-line-name` included.

    **Demonstrate dynamic overrides**: You can override this value at runtime with a system property.

    ```bash
    ./mvnw quarkus:dev -Dtrain-line-name=Local-Shuttle-01
    ```

3.  **Containerize the Application**

    Add the container image extension. Open `pom.xml` and add the `quarkus-container-image-podman` extension.

    ```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-container-image-podman</artifactId>
        <scope>provided</scope>
    </dependency>
    ```

    Build the container image. Run the following command to build a native executable and a corresponding container image.

    ```bash
    ./mvnw package -Pnative -Dquarkus.container-image.build=true
    ```

    Run the image. Run the container using Podman.

    ```bash
    podman run -it --rm -p 8080:8080 example/train-line-service:1.0.0-SNAPSHOT-runner
    ```

    Override the configuration in the container. Stop the container and restart it, this time overriding the `train-line-name` with an environment variable.

    ```bash
    podman run -it --rm -p 8080:8080 -e TRAIN_LINE_NAME=Express-Line-B example/train-line-service:1.0.0-SNAPSHOT-runner
    ```

4.  **Save your work**

    Commit your changes to Git.

    ```bash
    git add .
    git commit -m "feat: Lab 2 complete - containerization and dynamic configuration"
    ```

## Final Check

- [ ] Can you debug your application with a breakpoint in dev mode?
- [ ] Can you override the `train-line-name` with an environment variable?
- [ ] Can you build and run the container image?
- [ ] Have you committed your work to Git?