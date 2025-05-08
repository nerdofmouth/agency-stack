FROM node:18-slim

# AgencyStack MCP Server Container
# Following Charter principle of Strict Containerization

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["node", "server.js"]
