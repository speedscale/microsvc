# Multi-stage build for Next.js frontend
FROM node:20-alpine AS builder

WORKDIR /app

# Install curl for debugging and update npm to latest version
RUN apk add --no-cache curl && \
    npm install -g npm@latest

# Copy package files  
COPY package.json package-lock.json ./

# Install dependencies with npm ci for faster, reliable installs
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set timeout 60000 && \
    npm config set fetch-retries 3 && \
    npm ci --no-audit --loglevel error

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Runtime image
FROM node:20-alpine

WORKDIR /app

# Create non-root user (Alpine syntax)
RUN addgroup -g 1001 nodejs && \
    adduser -u 1001 -G nodejs -s /bin/sh -D nextjs

# Copy built application
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Change ownership
RUN chown -R nextjs:nodejs /app

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Health check (using curl which is available in Alpine)
RUN apk add --no-cache curl
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Run the application
CMD ["node", "server.js"]