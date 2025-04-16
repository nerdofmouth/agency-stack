# Dockerfile for AgencyStack Dashboard
# Multi-stage build for optimized production image

# === Build Stage ===
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Create required directories and ensure files exist
RUN mkdir -p public
RUN touch next.config.js

# Copy application code
COPY . .

# Build the Next.js application
RUN npm run build

# === Production Stage ===
FROM node:18-alpine AS runner

WORKDIR /app

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Create required directories
RUN mkdir -p public

# Copy production dependencies
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
RUN npm ci --only=production

# Copy built application
COPY --from=builder /app/.next ./.next/
COPY --from=builder /app/public ./public/
COPY --from=builder /app/next.config.js ./

# User and permissions
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE 3000

# Start application
CMD ["npm", "start"]
