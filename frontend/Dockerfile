# Multi-stage build for Next.js frontend
FROM --platform=$BUILDPLATFORM node:20-slim AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Runtime image
FROM --platform=$TARGETPLATFORM node:20-slim

WORKDIR /app

# Create non-root user
RUN addgroup --gid 1001 nodejs && \
    adduser --uid 1001 --gid 1001 nextjs

# Copy package files for production install
COPY --from=builder /app/package*.json ./

# Install dependencies including Next.js for runtime
RUN npm ci --omit=dev && npm install next && npm cache clean --force

# Copy built application
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next

# Change ownership
RUN chown -R nextjs:nodejs /app

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1

# Run the application
CMD ["npx", "next", "start"]