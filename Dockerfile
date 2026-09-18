###############################################
# STAGE 1 : Builder — installation Node/Yarn, clone du repo, build
###############################################
FROM debian:stretch-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# --- Installation de Node.js ---
ENV NODE_VERSION=9.0.0
RUN set -ex \
    && curl -fsSLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
    && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
    && rm "node-v$NODE_VERSION-linux-x64.tar.xz"

# --- Installation de Yarn ---
ENV YARN_VERSION=1.2.1
RUN set -ex \
    && curl -fsSLO "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
    && mkdir -p /opt/yarn \
    && tar -xzf "yarn-v$YARN_VERSION.tar.gz" -C /opt/yarn --strip-components=1 \
    && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn/bin/yarnpkg /usr/local/bin/yarnpkg \
    && rm "yarn-v$YARN_VERSION.tar.gz"

# --- Clonage et build de l'app ---
WORKDIR /var/local/
RUN git clone --depth 1 https://github.com/pontus-vision/pontusvision-extract-discovery

WORKDIR /var/local/pontusvision-extract-discovery/dataprep-webapp/
RUN npm install \
    && npm run build


###############################################
# STAGE 2 : Image finale — nginx pour servir les fichiers statiques
###############################################
FROM nginx:1.25-alpine

# Copie de la configuration nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copie du build statique généré par le stage précédent
# Adapter "dist" si le dossier de sortie du build a un autre nom (build, www...)
COPY --from=builder /var/local/pontusvision-extract-discovery/dataprep-webapp/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
