# Multi-stage build for Next.js frontend
FROM node:20 AS builder

WORKDIR /app

# Update npm to latest version
RUN npm install -g npm@latest

# Copy package files  
COPY package.json package-lock.json ./

# Install dependencies with npm ci for faster, reliable installs
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set fetch-retries 3 && \
    npm ci --no-audit --loglevel error

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Runtime image
FROM node:20

WORKDIR /app

# Create non-root user
RUN groupadd -g 1001 nodejs && \
    useradd -u 1001 -g nodejs -s /bin/bash nextjs

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

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Run the application
CMD ["node", "server.js"]