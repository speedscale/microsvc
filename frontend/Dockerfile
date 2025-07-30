# Multi-stage build for Next.js frontend
FROM --platform=$BUILDPLATFORM node:20-slim AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --no-audit --no-fund

# Copy source code
COPY . .

# Set production environment for optimal build
ENV NODE_ENV=production

# Build the application with standalone output
RUN npm run build

# Runtime image - use distroless for minimal size
FROM --platform=$TARGETPLATFORM gcr.io/distroless/nodejs20-debian12

WORKDIR /app

# Copy only the standalone Next.js build
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Switch to non-root user (distroless default is nonroot:65534)
USER 65534

# Expose port
EXPOSE 3000

# Run the application
CMD ["server.js"]