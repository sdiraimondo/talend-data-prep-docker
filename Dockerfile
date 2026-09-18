###############################################
# Dockerfile multi-arch (linux/amd64 + linux/arm64)
# Projet : pontusvision-extract-discovery (front-end)
# Source amont clonee depuis https://github.com/Talend/data-prep/
###############################################

# --- Choix de Node.js : 10.24.1 (LTS Dubnium, derniere 10.x) ---
# Le Dockerfile original utilisait Node 9.0.0. On bascule sur 10.24.1
# car nodejs.org distribue un binaire officiel linux-arm64 pour la
# 10.24.1 (la branche 10.x a introduit le support ARM64 a partir de
# la 10.16.0). La 9.0.0 n'a jamais eu de build arm64 officiel : elle
# n'aurait pas pu etre utilisee sur linux/arm64 avec buildx.
# 10.24.1 reste une LTS supportee par Talend data-prep au moment du
# clonage, donc le `npm install` du repo continue de fonctionner.

# --- Choix de TARGETARCH ---
# `docker buildx build` injecte automatiquement la variable TARGETARCH
# (amd64 ou arm64) selon la plateforme demandee. C'est ce mecanisme
# qui permet de telecharger le bon binaire Node ci-dessous.
# Pour un build classique (`docker build` sans buildx), TARGETARCH
# n'est PAS positionne : on retombe alors sur `uname -m`, qui retourne
# "x86_64" sur amd64 et "aarch64" sur arm64. Le mapping shell traduit
# vers le suffixe d'archive officiel Node : amd64 -> x64, arm64 -> arm64.
# Resultat : un seul Dockerfile marche dans les deux modes.

###############################################
# STAGE 1 : builder
#   - clone le repo Git,
#   - installe Node 10.24.1 + Yarn 1.2.1 selon TARGETARCH,
#   - lance npm install + npm run build (sortie -> ./dist)
###############################################
FROM debian:stretch-slim AS builder

# IMPORTANT : ARG doit etre RE-DECLARE apres chaque FROM (limitation Docker).
# Sans cette ligne, ${TARGETARCH} serait vide dans ce stage.
ARG TARGETARCH

ENV NODE_VERSION=10.24.1 \
    YARN_VERSION=1.2.1

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Utilisateur non-root (uid 1000), comme dans le Dockerfile original,
# pour executer npm install / npm run build sans privileges root.
RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

# --- Installation de Node.js ---
# Priorite : TARGETARCH (buildx). Fallback : uname -m (docker build
# classique). Tout autre cas -> echec explicite.
RUN set -eux; \
    case "${TARGETARCH:-}" in \
      amd64) NODE_ARCH=x64 ;; \
      arm64) NODE_ARCH=arm64 ;; \
      "")    HOST_MACHINE=$(uname -m); \
             case "$HOST_MACHINE" in \
               x86_64)  NODE_ARCH=x64 ;; \
               aarch64) NODE_ARCH=arm64 ;; \
               *) echo "Architecture non supportee : $HOST_MACHINE" >&2; exit 1 ;; \
             esac ;; \
      *) echo "TARGETARCH non supporte : ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    echo "==> Installation Node ${NODE_VERSION} (linux-${NODE_ARCH})"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"; \
    tar -xJf "node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" -C /usr/local --strip-components=1; \
    rm "node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"; \
    ln -s /usr/local/bin/node /usr/local/bin/nodejs

# --- Installation de Yarn 1.2.1 (tarball unique, pas de mapping arch) ---
RUN set -eux; \
    curl -fsSLO "https://github.com/yarnpkg/yarn/releases/download/v${YARN_VERSION}/yarn-v${YARN_VERSION}.tar.gz"; \
    mkdir -p /opt/yarn; \
    tar -xzf "yarn-v${YARN_VERSION}.tar.gz" -C /opt/yarn --strip-components=1; \
    ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn; \
    rm "yarn-v${YARN_VERSION}.tar.gz"

WORKDIR /var/local

# Clone Git (conserve depuis l'original) puis build.
RUN git clone --depth 1 https://github.com/Talend/data-prep.git /var/local \
    && chown -R node:node /var/local

USER node

RUN npm install \
    && npm run build


###############################################
# STAGE 2 : runtime — nginx:alpine sert le contenu de ./dist
# (nginx:alpine est deja une image multi-arch officielle, on n'a
#  PAS besoin de gerer TARGETARCH ici : buildx la selectionne
#  automatiquement pour chaque plateforme cible.)
###############################################
FROM nginx:alpine

LABEL org.opencontainers.image.title="pontusvision-extract-discovery" \
      org.opencontainers.image.description="Front-end pontusvision-extract-discovery (multi-arch amd64/arm64)"

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /var/local/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
