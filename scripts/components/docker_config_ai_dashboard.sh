#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: docker_config_ai_dashboard.sh
# Path: /scripts/components/docker_config_ai_dashboard.sh
#

# Enforce containerization (prevent host contamination)


# Create Docker configuration
create_docker_config() {
  log "INFO" "Creating Docker configuration..."
  
  # Create Dockerfile
  cat > "${APP_DIR}/Dockerfile" << 'EOF'
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
WORKDIR /app

# Copy package.json and install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment variables
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# Build the application
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy only necessary files
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

# Start Next.js
CMD ["node", "server.js"]
EOF

  # Create .dockerignore
  cat > "${APP_DIR}/.dockerignore" << 'EOF'
node_modules
.next
.git
.gitignore
README.md
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF

  # Create docker-compose.yml
  cat > "${DOCKER_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  ai-dashboard:
    build:
      context: ${APP_DIR}
    container_name: ai-dashboard-${CLIENT_ID}
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=${PORT}
      - NEXT_PUBLIC_APP_VERSION=1.0.0
      - CLIENT_ID=${CLIENT_ID}
      - OLLAMA_API_URL=http://ollama-${CLIENT_ID}:11434
      - LANGCHAIN_API_URL=http://langchain-${CLIENT_ID}:5111
      - NEXT_PUBLIC_DASHBOARD_API_URL=/api
      - NEXT_PUBLIC_OLLAMA_API_URL=/api/ollama
      - NEXT_PUBLIC_LANGCHAIN_API_URL=/api/langchain
      - OPENAI_ENABLED=${OPENAI_ENABLED:-false}
      - SETTINGS_PATH=/opt/agency_stack/clients
    volumes:
      - ${CLIENT_DIR}/ai/dashboard:/opt/agency_stack/clients/${CLIENT_ID}/ai/dashboard
    networks:
      - agency_stack
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ai-dashboard-${CLIENT_ID}.rule=Host(\`ai.${DOMAIN}\`)"
      - "traefik.http.routers.ai-dashboard-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.ai-dashboard-${CLIENT_ID}.tls=true"
      - "traefik.http.services.ai-dashboard-${CLIENT_ID}.loadbalancer.server.port=${PORT}"

networks:
  agency_stack:
    external: true
EOF

  log "INFO" "Created Docker configuration at ${DOCKER_DIR}/docker-compose.yml"
}

# Setup Docker environment
setup_docker() {
  log "INFO" "Setting up Docker environment..."
  
  # Check if the Docker network exists, if not create it
  if ! docker network ls | grep -q "agency_stack"; then
    log "INFO" "Creating Docker network: agency_stack"
    docker network create agency_stack
  fi
  
  # Build the Docker image
  log "INFO" "Building Docker image..."
  cd "${APP_DIR}" && docker compose -f "${DOCKER_DIR}/docker-compose.yml" build

  # Start the container
  log "INFO" "Starting Docker container..."
  docker compose -f "${DOCKER_DIR}/docker-compose.yml" up -d
  
  log "INFO" "Docker environment setup complete"
}
