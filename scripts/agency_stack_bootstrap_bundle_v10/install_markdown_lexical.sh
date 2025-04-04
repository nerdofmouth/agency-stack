#!/bin/bash
# install_markdown_lexical.sh - Document editing + collaboration system

echo "📄 Installing Markdown + Lexical (Document Editing & Collaboration)..."

# Create directory for Markdown editor
mkdir -p /opt/markdown-editor
mkdir -p /opt/markdown-editor/data
mkdir -p /opt/markdown-editor/config

# Create docker-compose.yml for Hedgedoc (formerly CodiMD)
cat > /opt/markdown-editor/docker-compose.yml <<EOL
version: '3'
services:
  database:
    image: postgres:13-alpine
    container_name: markdown_db
    environment:
      - POSTGRES_USER=hedgedoc
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=hedgedoc
    volumes:
      - ./data/database:/var/lib/postgresql/data
    restart: always
    networks:
      - markdown_network

  hedgedoc:
    image: quay.io/hedgedoc/hedgedoc:1.9.6
    container_name: hedgedoc
    environment:
      - CMD_DB_URL=postgres://hedgedoc:password@database:5432/hedgedoc
      - CMD_DOMAIN=docs.example.com
      - CMD_URL_ADDPORT=false
      - CMD_PROTOCOL_USESSL=true
      - CMD_ALLOW_FREEURL=true
      - CMD_DEFAULT_PERMISSION=editable
      - CMD_SESSION_SECRET=change_this_to_random_secret
      - CMD_IMAGE_UPLOAD_TYPE=filesystem
      - CMD_ALLOW_EMAIL_REGISTER=false
    volumes:
      - ./data/uploads:/hedgedoc/public/uploads
      - ./config/config.json:/hedgedoc/config.json:ro
    depends_on:
      - database
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.hedgedoc.rule=Host(\`docs.example.com\`)"
      - "traefik.http.routers.hedgedoc.entrypoints=websecure"
      - "traefik.http.routers.hedgedoc.tls.certresolver=myresolver"
      - "traefik.http.services.hedgedoc.loadbalancer.server.port=3000"
    networks:
      - markdown_network
      - traefik

  # Git server for document version control
  gitea:
    image: gitea/gitea:1.18
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=database:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=hedgedoc
      - GITEA__database__PASSWD=password
      - GITEA__server__DOMAIN=git.example.com
      - GITEA__server__ROOT_URL=https://git.example.com/
      - GITEA__server__SSH_DOMAIN=git.example.com
    volumes:
      - ./data/gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    restart: always
    depends_on:
      - database
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gitea.rule=Host(\`git.example.com\`)"
      - "traefik.http.routers.gitea.entrypoints=websecure"
      - "traefik.http.routers.gitea.tls.certresolver=myresolver"
      - "traefik.http.services.gitea.loadbalancer.server.port=3000"
    networks:
      - markdown_network
      - traefik

  # React-based Markdown editor with Lexical integration
  markdown-frontend:
    image: nginx:alpine
    container_name: markdown-frontend
    volumes:
      - ./data/frontend:/usr/share/nginx/html
      - ./config/nginx.conf:/etc/nginx/conf.d/default.conf
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.markdown-frontend.rule=Host(\`editor.example.com\`)"
      - "traefik.http.routers.markdown-frontend.entrypoints=websecure"
      - "traefik.http.routers.markdown-frontend.tls.certresolver=myresolver"
      - "traefik.http.services.markdown-frontend.loadbalancer.server.port=80"
    networks:
      - markdown_network
      - traefik

networks:
  markdown_network:
  traefik:
    external: true
EOL

# Create config.json for Hedgedoc
cat > /opt/markdown-editor/config/config.json <<EOL
{
  "production": {
    "domain": "docs.example.com",
    "protocolUseSSL": true,
    "allowOrigin": ["docs.example.com", "editor.example.com", "git.example.com"],
    "sessionSecret": "change_this_to_random_secret",
    "oauth2": {
      "clientID": "hedgedoc",
      "clientSecret": "change_this_to_random_secret",
      "authorizationURL": "https://keycloak.example.com/auth/realms/foss-stack/protocol/openid-connect/auth",
      "tokenURL": "https://keycloak.example.com/auth/realms/foss-stack/protocol/openid-connect/token",
      "userProfileURL": "https://keycloak.example.com/auth/realms/foss-stack/protocol/openid-connect/userinfo",
      "scope": "openid email profile"
    }
  }
}
EOL

# Create nginx configuration for frontend
mkdir -p /opt/markdown-editor/config
cat > /opt/markdown-editor/config/nginx.conf <<EOL
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API proxy to Hedgedoc
    location /api/ {
        proxy_pass http://hedgedoc:3000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Create setup script for React-based editor with Lexical integration
mkdir -p /opt/markdown-editor/scripts
cat > /opt/markdown-editor/scripts/setup-frontend.sh <<EOL
#!/bin/bash
# Setup script for the React-based markdown editor with Lexical

# Create frontend directory
mkdir -p /opt/markdown-editor/data/frontend

# Download and install Node.js
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# Clone the repository
git clone https://github.com/facebook/lexical.git /tmp/lexical
cd /tmp/lexical

# Install dependencies
npm install

# Build the editor
cd packages/lexical-playground
npm run build

# Copy the build files to the frontend directory
cp -r dist/* /opt/markdown-editor/data/frontend/

# Install the Markdown plugin
cd ../../packages/lexical-markdown
npm install
npm run build

# Create a simple index.html that loads the editor
cat > /opt/markdown-editor/data/frontend/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Markdown Editor</title>
    <link rel="stylesheet" href="assets/index.css">
</head>
<body>
    <div id="editor-container" style="height: 100vh;"></div>
    <script src="assets/index.js"></script>
    <script>
        // Initialize the editor with Markdown support
        document.addEventListener('DOMContentLoaded', function() {
            window.LexicalMarkdownEditor.init('#editor-container', {
                markdown: true,
                collaboration: {
                    serverUrl: window.location.origin + '/api/collaboration'
                },
                git: {
                    serverUrl: 'https://git.example.com'
                }
            });
        });
    </script>
</body>
</html>
EOF

echo "Frontend setup completed"
EOL

# Make the script executable
chmod +x /opt/markdown-editor/scripts/setup-frontend.sh

# Create Git synchronization script
cat > /opt/markdown-editor/scripts/sync-git.sh <<EOL
#!/bin/bash
# Synchronize Markdown documents with Git repository

DOCS_DIR="/opt/markdown-editor/data/uploads"
GIT_REPO="/opt/markdown-editor/data/git-sync"
COMMIT_MSG="Auto-sync documents $(date '+%Y-%m-%d %H:%M:%S')"

# Initialize Git repo if it doesn't exist
if [ ! -d "\$GIT_REPO/.git" ]; then
  mkdir -p "\$GIT_REPO"
  cd "\$GIT_REPO"
  git init
  echo "# Markdown Documents" > README.md
  git add README.md
  git commit -m "Initial commit"
fi

# Sync documents to Git repo
rsync -av --delete "\$DOCS_DIR/" "\$GIT_REPO/"

# Commit changes
cd "\$GIT_REPO"
git add .
git commit -m "\$COMMIT_MSG" || echo "No changes to commit"

# Push to remote if configured
if git remote | grep -q origin; then
  git push origin master
fi

echo "Git synchronization completed"
EOL

# Make the script executable
chmod +x /opt/markdown-editor/scripts/sync-git.sh

# Create systemd service for Git synchronization
cat > /etc/systemd/system/markdown-git-sync.service <<EOL
[Unit]
Description=Markdown Git Synchronization
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/markdown-editor/scripts/sync-git.sh
User=root
Group=root
EOL

# Create systemd timer for hourly synchronization
cat > /etc/systemd/system/markdown-git-sync.timer <<EOL
[Unit]
Description=Run Markdown Git Synchronization hourly

[Timer]
OnCalendar=*:00
Persistent=true

[Install]
WantedBy=timers.target
EOL

# Install git for the sync script to work
apt-get install -y git

echo "✅ Markdown + Lexical document editing system installed successfully!"
echo "📋 Configuration:"
echo "  1. Update domain names in /opt/markdown-editor/docker-compose.yml"
echo "  2. Update config.json with your actual configuration"
echo "  3. Set up the frontend by running: /opt/markdown-editor/scripts/setup-frontend.sh"
echo "  4. Configure Git repositories in Gitea after startup"
echo "🚀 To start the services:"
echo "  cd /opt/markdown-editor && docker-compose up -d"
echo "⏱️ To enable automatic Git synchronization:"
echo "  systemctl daemon-reload"
echo "  systemctl enable markdown-git-sync.timer"
echo "  systemctl start markdown-git-sync.timer"
echo "🌐 Access your services at:"
echo "  - Document collaboration: https://docs.example.com"
echo "  - Git repository: https://git.example.com"
echo "  - Markdown editor: https://editor.example.com"
