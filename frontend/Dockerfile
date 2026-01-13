# Image Frontend Angular personnalisée
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Installer Node.js et npm
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installer Angular CLI
RUN npm install -g @angular/cli http-server

WORKDIR /app

# Copier le projet Angular
COPY . .

# Installer les dépendances et construire
RUN npm install && ng build --configuration=production

EXPOSE 4200
CMD ["http-server", "dist/frontend/browser", "-p", "4200", "-c-1"]
