# NestJS Microservices + Kubernetes Architecture and Deployment

Monorepo-based NestJS microservices deployed with Kubernetes, Skaffold and Kustomize. This document explains architecture, local development and deployment workflows.

**Table of contents**

- [1\. Architectural Overview](#overview)
  - [1.1 Core Services](#core-services)
- [2\. Prerequisites](#prerequisites)
- [3\. Local Development Procedure](#local-dev)
- [4\. Technology Stack Deep Dive](#tech-stack)
  - [4.1 Docker and Multi-Stage Builds](#docker-multistage)
  - [4.2 Skaffold Orchestration](#skaffold)
- [5\. Kubernetes Configuration and Deployment](#k8s)
  - [5.1 Kustomize Overlays](#kustomize)
  - [5.2 Service and Ingress](#service-ingress)
- [6\. Autoscaling with KEDA](#keda)

## 1\. Architectural Overview

This project is built as a **monorepo** containing independent, containerized microservices. Services are implemented using **NestJS** and managed by **Kubernetes**. Core components include auth-service and billing-service. Below is a summary of responsibilities.

### 1.1 Core Services

- **Authentication Service (auth-service)**: Responsible for user authentication and authorization. Exposed on internal port `3001`.  
  The auth-service is the gatekeeper — other services rely on it to verify identity and authorization.
- **Billing Service (billing-service)**: Handles billing logic and payment processing. Exposed on internal port `3002`.  
  The billing-service manages financial transactions and subscription logic.

## 2\. Prerequisites

Install and configure the following tools before running local development:

- **Docker** — build and manage container images.
- **Kubernetes (k8s)** — local cluster (Minikube, Docker Desktop, etc.).
- **Skaffold CLI** — automates build, push, deploy and sync workflows.
- **kubectl CLI** — interact with the Kubernetes cluster.
- **pnpm** — package manager used inside containers.

## 3\. Local Development Procedure

The local environment is activated using a single Skaffold command that handles build, deployment and live-reloading.

### 3.1 Execution Command

    skaffold dev -p local

This uses the `local` profile in `skaffold.yml` and enables file synchronization for hot-reloading.

## 4\. Technology Stack Deep Dive

The architecture is designed for a great developer experience and a robust CI/CD pipeline.

### 4.1 Docker and Multi-Stage Builds

The repository uses a single multi-stage Dockerfile with the following logical stages:

- **base**: Shared foundation with core dependencies.
- **deps**: Installs project dependencies and leverages caching via `pnpm-lock.yaml`.
- **dev-base**: Adds source code for development images to enable hot-reload and live-sync.
- **builder**: Builds production code and prunes dev dependencies.
- **\*-prod**: Final runtime images with minimal attack surface.
- **\*-dev**: Development images optimized for fast feedback and hot-reloading.

### 4.2 Skaffold Orchestration

Skaffold automates building, pushing and deploying images and supports different profiles for dev and production.

- **skaffold dev** — builds \*-dev images, deploys to local cluster, watches for changes and updates containers with file sync.
- **skaffold run** — builds \*-prod images, pushes to registry and deploys to target environment (used in CI/CD).

## 5\. Kubernetes Configuration and Deployment

Manifests are managed with **Kustomize**, enabling a base configuration and environment overlays.

### 5.1 Kustomize Overlays

- **.k8s/base** — base resource definitions (Deployments, Services, Ingress).
- **local profile** — overlay tailored for local development (dev features, different image tags etc.).
- **development / staging / production profiles** — environment-specific overlays controlling image tags, replica counts and resource limits.

### 5.2 Service and Ingress

Service manifests (e.g. `auth.service.yml`, `billing.service.yml`) provide stable internal endpoints. The `ingress.yml` configures an ingress resource using the nginx ingress controller as an API gateway.

- `https://[host]/auth/` routes to the auth-service.
- `https://[host]/billing/` routes to the billing-service.

The annotation `nginx.ingress.kubernetes.io/rewrite-target: /$2` strips the path prefix before forwarding to the service.

## 6\. Autoscaling with KEDA

The `skaffold.yml` includes Helm chart definitions for **KEDA** and its HTTP add-on.

- **KEDA's Role** — scale deployments in and out based on HTTP requests and other event sources.
- **Integration** — Skaffold deploys KEDA automatically so HTTP-driven scaling rules can be added without manual setup.
