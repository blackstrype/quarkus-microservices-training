# Lab 2: Dynamic Configuration & Deployment

## Objective

In this lab, you will configure your microservice to be environment-agnostic using dynamic configuration. You will then containerize and deploy your application to a local Kubernetes cluster, which is a key objective of the training.

## Theme Integration

As a key component of the Smart City Transit Network, your `train-line-service` needs to be flexible and deployable. In this lab, we will configure the service with a unique `train-line-name` and deploy it to the Kubernetes cluster.

## Instructions

1.  **Debugging and Logging in Dev Mode**

    Introduce the `Logger`. Open `StatusResource.java` and inject a logger. Add a log statement.

    TODO: Replace jboss `Logger` injected instances with quarkus `Log`

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
            logger.debug("Checking the status of the train line service...");
            return "Operational";
        }
    }
    ```

    Run the code with `quarkus dev`.

    **Run with the Debugger Attached**: Attach your debugger to port `5005`.

    ```bash
    ./mvnw quarkus:dev
    ```

    Set a breakpoint on the logger line in `status()` and re-run a curl command. Observe the debugger stopping at the breakpoint.

    **Demonstrate Live Reload**: While the debugger is still attached, add a new logging line
    
    ```java
    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String status() {
        logger.debug("Checking the status of the train line service...");
        logger.info("Status check successful.");
        return "Operational";
    }
    ```

    - Observe that the IDE running the debugger detects a code change (Accept the code change).
    - Set a breakpoint on the new logging line and run a new `/status` endpoint call.
    - Change the return statement to `return "Running smoothly";`.
    - Re-run a `/status` call and observe the new behavior.

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

    Observe the changes. Use `curl` to access the endpoint and observe the new log message with the `train-line-name` included.
    ```bash
    curl http://localhost:8080/status
    ```

    **Demonstrate dynamic overrides**: You can override this value at runtime with a system property.

    ```bash
    ./mvnw quarkus:dev -Dtrain-line-name=Local-Shuttle-01
    ```

3.  **Containerize the Application**

    Add the container image extension. Open `pom.xml` and add the `quarkus-container-image-podman` and the `quarkus-container-image-jib` extension.

    ```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-container-image-jib</artifactId>
    </dependency>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-container-image-podman</artifactId>
    </dependency>
    ```

    Add some config to automatically tag and name the image. This will make it easier to run from a known image group/name/tag.

    ```properties
    quarkus.container-image.group=localhost/smessner
    quarkus.container-image.name=train-line-service
    quarkus.container-image.tag=latest
    ```

    Specify the the container build options

    ```properties
    ## Container native image build properties
    quarkus.native.container-build=true
    quarkus.native.container-runtime=podman
    quarkus.container-image.build=true
    quarkus.container-image.builder=podman
    ```

    `quarkus.container-image.build=true` will specify to produce a container image at build time.
    `quarkus.native.container-build=true` will specify to build the native Linux executable within a container (not using the local GraalVM/Mandrel tooling).
    `quarkus.container-image.builder=podman` explicitly specifies to use podman as the container builder.
    `quarkus.native.container-runtime=podman` explicitly specifies to use podman as the container runtime.

    **Note**: If you don't want container-tool-specific configuration in your app properties you can add it into your global mvn config and use the quarkus-container-image extension in your pom. Quarkus should be able to auto-detect the container builder and runtime automatically, but sometimes this doesn't always work as intended. [source](https://quarkus.io/guides/building-native-image#container-runtime)

    Build the container image.

    ```bash
    quarkus build --native
    ```

    Demonstrate that the built image is indeed using a native binary.

    ```bash
    podman run -it -p 8080:8080 --entrypoint /bin/sh localhost/smessner/train-line-service:latest
    ls application
    java -version
    ./application
    ˆC
    exit
    ```

    Run the container using Podman.

    ```bash
    podman run -it -p 8080:8080 localhost/smessner/train-line-service:latest
    ```
    
    Add a production profile to `application.properties` and rebuild:
    ```properties
    %prod.train-line-name=Production-Line-C
    ```

    Override the configuration in the container by adding the `train-line-name` with an environment variable and running in production mode.

    ```bash
    podman run -it --rm -p 8080:8080 -e QUARKUS_PROFILE=dev -e TRAIN_LINE_NAME=Express-Line-B localhost/smessner/train-line-service:latest
    ```

    Test a few curl commands on the /status endpoint to see how the train-line-name changes in between prod and dev profiles.

4.  **Save your work**

    Commit your changes to Git.

    ```bash
    git add .
    git commit -m "feat: Lab 2 complete - containerization and dynamic configuration"
    ```

## Final Check

- [ ] Can you debug your application with a breakpoint in dev mode?
- [ ] Can you override the `train-line-name` with an environment variable?
- [ ] Can you build and run the native binary container image?
- [ ] Have you committed your work to Git?

## Discussion Points

 - [Runtime Performance Comparisons](https://quarkus.io/blog/runtime-performance/)
 - [Building a Container Image](https://quarkus.io/guides/container-image#building)
 - [Building a Native Image](https://quarkus.io/guides/building-native-image#container-runtime)
 - [Configuration Reference](https://quarkus.io/guides/config-reference)