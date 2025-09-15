# Smart City Transit Labs Overview

## Theme: The Smart City Transit Network

This training program uses a unified theme of a **Smart City Transit Network** to make the concepts of microservices more engaging and relatable. Each participant will develop a microservice that represents a single train line within this network. This service will own its own data and communicate with other services to provide a cohesive experience.

---

### Lab 1: Getting Started with Quarkus

- **Objective:** Create a foundational Quarkus application.
- **Theme:** Establish the core `train-line-service` with a simple health check endpoint. This is the starting point for your microservice.

### Lab 2: Dynamic Configuration & Deployment

- **Objective:** Configure the application for different environments.
- **Theme:** The `train-line-service` is now ready for deployment. This lab focuses on containerizing the application and configuring it with a unique `train-line-name` for deployment to a local Kubernetes cluster.

### Lab 3: Data Access with Panache

- **Objective:** Introduce data persistence using Panache ORM.
- **Theme:** Your `train-line-service` needs to manage its own data. This lab focuses on creating a `TrainStop` entity and a corresponding REST API to manage the scheduled stops for your train line.

### Lab 4: Documenting Endpoints with OpenAPI

- **Objective:** Document the `train-line-service` API for other services to consume.
- **Theme:** As a microservice, your `train-line-service` needs to provide a clear contract. This lab focuses on using OpenAPI to automatically generate and enhance API documentation, making it easier for other services (like the `station-service`) to integrate with yours.

### Lab 5: Securing and Consuming a Protected API

- **Objective:** Secure the `train-line-service` and consume a protected API.
- **Theme:** The `station-service` is the single source of truth for all station data, and it is protected by Keycloak. This lab focuses on how your `train-line-service` can securely authenticate with Keycloak to get an access token and then use that token to make a secure call to the `station-service`.

### Lab 6: Resilience

- **Objective:** Implement resilience patterns to ensure service stability.
- **Theme:** The `DerailerService` randomly blocks stations and shuts down train lines. This lab focuses on implementing resilience patterns like **Circuit Breaker** and **Retry** to handle service failures and maintain the stability of your `train-line-service`.

### Lab 7: Reactive Messaging & Monitoring

- **Objective:** Implement asynchronous communication with Azure Service Bus.
- **Theme:** The `StationService` publishes "blocked" and "unblocked" messages to the Azure Service Bus. This lab focuses on how your `train-line-service` can react to these events in real-time, providing a robust and responsive system.
