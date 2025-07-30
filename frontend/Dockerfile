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

# Runtime image - use Alpine for Colima compatibility
FROM --platform=$TARGETPLATFORM node:20-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Copy only the standalone Next.js build
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Change ownership to non-root user
RUN chown -R nextjs:nodejs /app

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Run the application
CMD ["server.js"]