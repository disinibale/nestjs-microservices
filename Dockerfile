# ---- Base Stage ----
# This is our shared foundation. All other stages build on this.
FROM node:24-slim AS base
# Install all common system dependencies ONCE.
RUN apt-get update && apt-get install -y procps python3 make g++ && rm -rf /var/lib/apt/lists/*
# Install pnpm globally ONCE.
RUN npm install -g pnpm


# ---- Dependencies Stage ----
# This stage installs all node_modules. It's separate so we can cache it.
FROM base AS deps
WORKDIR /usr/src/app
# Copy ONLY the package files for both services
COPY auth-service/package.json auth-service/pnpm-lock.yaml ./auth-service/
COPY billing-service/package.json billing-service/pnpm-lock.yaml ./billing-service/
# Install dependencies for both services in one go
RUN cd auth-service && pnpm install --frozen-lockfile
RUN cd billing-service && pnpm install --frozen-lockfile


# ---- Development Base Stage ----
# This stage adds the source code on top of the dependencies.
# Our dev images will be based on this, so they are complete at startup.
FROM deps AS dev-base
COPY auth-service/ ./auth-service/
COPY billing-service/ ./billing-service/


# ---- Builder Stage ----
# This stage builds the production code for both services.
FROM dev-base AS builder
RUN cd auth-service && pnpm run build
RUN cd billing-service && pnpm run build
# Prune dev dependencies for production
RUN cd auth-service && pnpm prune --prod
RUN cd billing-service && pnpm prune --prod


# ---- Production Image: Auth Service ----
FROM base AS auth-service-prod
ENV NODE_ENV=production
RUN groupadd --gid 1001 --system nodejs && \
    useradd --uid 1001 --system --gid nodejs --shell /bin/bash --create-home nodejs
WORKDIR /usr/src/app
# Copy ONLY the necessary built files from the builder stage
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/auth-service/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/auth-service/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/auth-service/package.json ./
USER nodejs
EXPOSE 3001
CMD ["node", "dist/main"]


# ---- Production Image: Billing Service ----
FROM base AS billing-service-prod
ENV NODE_ENV=production
RUN groupadd --gid 1001 --system nodejs && \
    useradd --uid 1001 --system --gid nodejs --shell /bin/bash --create-home nodejs
WORKDIR /usr/src/app
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/billing-service/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/billing-service/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /usr/src/app/billing-service/package.json ./
USER nodejs
EXPOSE 3002
CMD ["node", "dist/main"]


# ---- Development Image: Auth Service ----
FROM dev-base AS auth-service-dev
ENV NODE_ENV=development
WORKDIR /usr/src/app/auth-service
EXPOSE 3001
CMD ["pnpm", "run", "start:dev"]


# ---- Development Image: Billing Service ----
FROM dev-base AS billing-service-dev
ENV NODE_ENV=development
WORKDIR /usr/src/app/billing-service
EXPOSE 3002
CMD ["pnpm", "run", "start:dev"]