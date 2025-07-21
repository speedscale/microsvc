# Multi-stage build for Next.js frontend
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files  
COPY package.json package-lock.json* ./

# Install dependencies with clean registry and skip optional deps that might cause issues
RUN npm config set registry https://registry.npmjs.org/ && \
    npm ci --omit=optional --loglevel error || npm install --omit=optional --loglevel error

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Runtime image
FROM node:20-alpine

WORKDIR /app

# Create non-root user
RUN addgroup --gid 1001 nodejs && \
    adduser --uid 1001 --gid 1001 nextjs

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