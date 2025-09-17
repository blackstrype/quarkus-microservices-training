# Lab 1: Getting Started with Quarkus

## Objective

In this lab, you will create a foundational Quarkus application that will serve as the basis for your "train line" microservice. You will get familiar with the Quarkus CLI, the `quarkus:dev` mode, and the project structure.

## Theme Integration

Each participant will create a microservice representing a single train line within the "Smart City Transit Network". In this lab, we'll create the `train-line-service` and a simple endpoint to return its status.

## Instructions

1.  **Create a new Quarkus Application**

    Use the Quarkus CLI to create a new project. The `quarkus:create` command will generate a full-featured project with a REST endpoint, a test, and a Dockerfile.

    ```bash
    quarkus create app com.example:train-line-service --extensions=rest,rest-jackson
    ```

    Navigate to the new `train-line-service` directory.

    ```bash
    cd train-line-service
    ```

2.  **Run the Application**

    Start the application in development mode.

    ```bash
    quarkus dev
    ```
    
    Access the endpoint using `curl`:
    ```bash
    curl http://localhost:8080/hello
    ```
    
    Observe the live reload feature by changing the return `"Hello from Quarkus REST";` in `src/main/java/com/example/GreetingResource.java` to `return "Hello, World!";`.
    
    Verify the change with `curl` again:
    ```bash
    curl http://localhost:8080/hello
    ```
3.  **Rename and Refactor the `GreetingResource`**

    Rename `GreetingResource.java` to `StatusResource.java` to better reflect its purpose in our Smart City theme.

    Change the path from `/hello` to `/status`.

    ```java
    // In StatusResource.java
    @Path("/status")
    public class StatusResource {

        @GET
        @Produces(MediaType.TEXT_PLAIN)
        public String status() {
            return "Operational";
        }
    }
    ```

    Rerun your `curl` tests.

4.  **Run the Tests**

    Still in quarkus dev mode, run the tests by tapping `r`. You can also start up dev mode and launch the tests by running the `test` goal.
    
    The tests are probably failing.

    ```bash
    ./mvnw quarkus:test
    ```

    Leave the application in dev mode.

5.  **Fix the Failing Test**

    Rename `GreetingResourceTest.java` to `StatusResourceTest.java`.

    Fix the failing test by changing the endpoint from `/hello` to `/status`.

    ```java
    // In StatusResourceTest.java
    @Test
    public void testHelloEndpoint() {
        given()
          .when().get("/status")
          .then()
             .statusCode(200)
             .body(is("Operational"));
    }
    ```

    At this point the live reload may not have picked up the change to the tests. You may have to quit dev mode and re-initiate a compile step. You can launch dev mode directly into the tests by using the `quarkus:test` goal.

    ```bash
    quarkus test
    ```

    **Note**: you can still run your tests with the standard `test` goal of maven

    ```bash
    mvn test
    ```

6.  **Save your work**

    Initialize your repository
    Commit your changes to Git.

    ```bash
    git init
    git add .
    git commit -m "feat: Lab 1 complete - initial train line service"
    ```

## Final Check

- [ ] Does your application start correctly with `./mvnw quarkus:dev` or `quarkus dev`?
- [ ] Can you access the `/status` endpoint in your browser?
- [ ] Do all of your tests pass?
- [ ] Have you committed your work to Git?

## Discussion Points

### Quarkus

- **[Quarkus Homepage](https://quarkus.io/)**: The main entry point, great for the official "elevator pitch" and latest news.
- **[What is Quarkus?](https://quarkus.io/get-started/)**: An introduction to the core concepts of "Supersonic Subatomic Java."
- **[Quarkus Guides](https://quarkus.io/guides/)**: A practical gateway for hands-on examples of almost every quarkus feature.

### MicroProfile

- **[Eclipse MicroProfile Homepage](https://microprofile.io/)**: Explains the project's mission to optimize Enterprise Java for microservices.
- **[MicroProfile Specifications](https://microprofile.io/specifications/)**: Lists all the specifications like Config, Health, Fault Tolerance, and REST Client.

### Jakarta EE

- **[Jakarta EE Homepage](https://jakarta.ee/)**: The official home for the evolution of Java EE under the Eclipse Foundation.
- **[What is Jakarta EE?](https://jakarta.ee/about/what-is-jakarta-ee/)**: Explains its purpose, its relationship to Java EE, and its role in modern cloud-native Java.
- **[Jakarta EE Specifications](https://jakarta.ee/specifications/)**: Shows the full breadth of the standards that Quarkus and other frameworks build upon, like Jakarta REST and Jakarta CDI.