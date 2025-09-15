# Lab 1: Getting Started with Quarkus

## Objective

In this lab, you will create a foundational Quarkus application that will serve as the basis for your "train line" microservice. You will get familiar with the Quarkus CLI, the `quarkus:dev` mode, and the project structure.

## Theme Integration

Each participant will create a microservice representing a single train line within the "Smart City Transit Network". In this lab, we'll create the `train-line-service` and a simple endpoint to return its status.

## Instructions

1.  **Create a new Quarkus Application**

    Use the Quarkus CLI to create a new project. The `quarkus:create` command will generate a full-featured project with a REST endpoint, a test, and a Dockerfile.

    ```bash
    quarkus create app com.example:train-line-service --extensions=resteasy-reactive,resteasy-reactive-jackson
    ```

    Navigate to the new `train-line-service` directory.

    ```bash
    cd train-line-service
    ```

2.  **Run the Application**

    Start the application in development mode.

    ```bash
    ./mvnw quarkus:dev
    ```

    Observe the live reload feature by changing the return `"Hello from RESTEasy Reactive";` in `src/main/java/com/example/GreetingResource.java` to `return "Hello, train line!";`. The change will be reflected automatically in the application.

    Access the endpoint in your browser:
    [http://localhost:8080/hello](http://localhost:8080/hello)

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

4.  **Run the Tests**

    Run the tests to see the continuous testing feature in action.

    ```bash
    ./mvnw test
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

6.  **Save your work**

    Commit your changes to Git.

    ```bash
    git add .
    git commit -m "feat: Lab 1 complete - initial train line service"
    ```

## Final Check

- [ ] Does your application start correctly with `./mvnw quarkus:dev`?
- [ ] Can you access the `/status` endpoint in your browser?
- [ ] Do all of your tests pass?
- [ ] Have you committed your work to Git?
