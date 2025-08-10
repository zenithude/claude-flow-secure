#!/bin/bash

# =================================================================
# Script de Build Docker Intelligent
# Teste plusieurs approches et choisit la meilleure
# =================================================================

set -euo pipefail

# Configuration
IMAGE_NAME="claude-flow-secure"
BACKUP_DOCKERFILE="Dockerfile.backup"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Sauvegarder le Dockerfile original
backup_dockerfile() {
    if [[ -f Dockerfile ]]; then
        cp Dockerfile "$BACKUP_DOCKERFILE"
        log_info "Dockerfile sauvegardé vers $BACKUP_DOCKERFILE"
    fi
}

# Restaurer le Dockerfile original
restore_dockerfile() {
    if [[ -f "$BACKUP_DOCKERFILE" ]]; then
        cp "$BACKUP_DOCKERFILE" Dockerfile
        log_info "Dockerfile restauré depuis $BACKUP_DOCKERFILE"
    fi
}

# Test de construction avec le Dockerfile actuel
test_current_dockerfile() {
    log_info "🔨 Test avec le Dockerfile actuel..."
    
    if docker build -t "$IMAGE_NAME:current-test" . --no-cache --quiet; then
        log_success "Construction réussie avec le Dockerfile actuel"
        return 0
    else
        log_error "Échec avec le Dockerfile actuel"
        return 1
    fi
}

# Créer le Dockerfile version Node.js 20
create_nodejs20_dockerfile() {
    log_info "📝 Création du Dockerfile Node.js 20..."
    
    cat > Dockerfile << 'EOF'
# Dockerfile pour Claude Flow Sécurisé
FROM node:20-alpine

# Métadonnées
LABEL maintainer="Claude Flow Security Setup"
LABEL description="Container sécurisé pour Claude Flow"
LABEL version="1.1"

# Installation des dépendances système minimales
RUN apk add --no-cache \
    git \
    bash \
    curl \
    jq \
    && rm -rf /var/cache/apk/*

# Mettre à jour npm vers la dernière version
RUN npm install -g npm@latest

# Installation de Claude Flow en tant que root (avant de changer d'utilisateur)
RUN npm install -g claude-flow@latest && \
    npm cache clean --force

# Création d'un utilisateur non-privilégié
RUN addgroup -g 1001 -S claude && \
    adduser -S claude -u 1001 -G claude -s /bin/bash

# Répertoires de travail
RUN mkdir -p /workspace /logs /var/run/claude && \
    chown -R claude:claude /workspace /logs /var/run/claude

# Configuration des permissions de sécurité
RUN mkdir -p /home/claude/.npm && \
    chown -R claude:claude /home/claude

# Donner accès à claude-flow à l'utilisateur non-privilégié
RUN chown -R claude:claude /usr/local/lib/node_modules/claude-flow 2>/dev/null || true && \
    chown claude:claude /usr/local/bin/claude-flow 2>/dev/null || true

# Basculer vers l'utilisateur non-privilégié
USER claude

# Répertoire de travail
WORKDIR /workspace

# Configuration des ports
EXPOSE 3000 8080

# Variables d'environnement sécurisées
ENV NODE_ENV=production
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NPM_CONFIG_FUND=false
ENV CLAUDE_FLOW_CONTAINER=true
ENV CLAUDE_FLOW_BIND_HOST=0.0.0.0

# Volumes pour persistance sécurisée
VOLUME ["/workspace", "/logs", "/var/run/claude"]

# Script de santé pour monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Point d'entrée par défaut
CMD ["claude-flow", "start", "--ui", "--port", "3000"]
EOF
}

# Créer le Dockerfile version installation locale
create_local_install_dockerfile() {
    log_info "📝 Création du Dockerfile installation locale..."
    
    cat > Dockerfile << 'EOF'
# Dockerfile Alternative pour Claude Flow Sécurisé
FROM node:20-alpine

# Métadonnées
LABEL maintainer="Claude Flow Security Setup"
LABEL description="Container sécurisé pour Claude Flow (installation locale)"
LABEL version="1.1-local"

# Installation des dépendances système minimales
RUN apk add --no-cache \
    git \
    bash \
    curl \
    jq \
    && rm -rf /var/cache/apk/*

# Mettre à jour npm vers la dernière version
RUN npm install -g npm@latest

# Création d'un utilisateur non-privilégié
RUN addgroup -g 1001 -S claude && \
    adduser -S claude -u 1001 -G claude -s /bin/bash

# Répertoires de travail
RUN mkdir -p /workspace /logs /var/run/claude /home/claude/.local/bin && \
    chown -R claude:claude /workspace /logs /var/run/claude /home/claude

# Basculer vers l'utilisateur non-privilégié
USER claude

# Répertoire de travail
WORKDIR /home/claude

# Installation locale de Claude Flow
RUN npm init -y && \
    npm install claude-flow@latest && \
    npm cache clean --force

# Créer un script wrapper
RUN echo '#!/bin/bash' > /home/claude/.local/bin/claude-flow && \
    echo 'exec node /home/claude/node_modules/.bin/claude-flow "$@"' >> /home/claude/.local/bin/claude-flow && \
    chmod +x /home/claude/.local/bin/claude-flow

# Ajouter le bin local au PATH
ENV PATH="/home/claude/.local/bin:$PATH"

# Répertoire de travail final
WORKDIR /workspace

# Configuration des ports
EXPOSE 3000 8080

# Variables d'environnement sécurisées
ENV NODE_ENV=production
ENV NPM_CONFIG_UPDATE_NOTIFIER=false
ENV NPM_CONFIG_FUND=false
ENV CLAUDE_FLOW_CONTAINER=true
ENV CLAUDE_FLOW_BIND_HOST=0.0.0.0

# Volumes pour persistance sécurisée
VOLUME ["/workspace", "/logs", "/var/run/claude"]

# Script de santé pour monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Point d'entrée par défaut
CMD ["claude-flow", "start", "--ui", "--port", "3000"]
EOF
}

# Test avec différentes approches
test_build_approaches() {
    local approaches=("current" "nodejs20" "local-install")
    local successful_approach=""
    
    for approach in "${approaches[@]}"; do
        log_info "🧪 Test de l'approche: $approach"
        
        case "$approach" in
            "current")
                # Tester le Dockerfile actuel s'il existe
                if [[ -f Dockerfile ]]; then
                    if test_current_dockerfile; then
                        successful_approach="current"
                        break
                    fi
                fi
                ;;
            "nodejs20")
                create_nodejs20_dockerfile
                if docker build -t "$IMAGE_NAME:nodejs20-test" . --no-cache --quiet; then
                    log_success "✅ Approche Node.js 20 réussie"
                    successful_approach="nodejs20"
                    break
                else
                    log_error "❌ Approche Node.js 20 échouée"
                fi
                ;;
            "local-install")
                create_local_install_dockerfile
                if docker build -t "$IMAGE_NAME:local-test" . --no-cache --quiet; then
                    log_success "✅ Approche installation locale réussie"
                    successful_approach="local-install"
                    break
                else
                    log_error "❌ Approche installation locale échouée"
                fi
                ;;
        esac
    done
    
    echo "$successful_approach"
}

# Construction finale
final_build() {
    local approach="$1"
    
    log_info "🏗️  Construction finale avec l'approche: $approach"
    
    case "$approach" in
        "nodejs20")
            create_nodejs20_dockerfile
            ;;
        "local-install")
            create_local_install_dockerfile
            ;;
        "current")
            restore_dockerfile
            ;;
    esac
    
    if docker build -t "$IMAGE_NAME:latest" . --no-cache; then
        log_success "🎉 Image finale construite: $IMAGE_NAME:latest"
        return 0
    else
        log_error "❌ Échec de la construction finale"
        return 1
    fi
}

# Test de validation rapide
quick_validation() {
    log_info "🔍 Validation rapide de l'image..."
    
    # Test des versions
    local node_version=$(docker run --rm "$IMAGE_NAME:latest" node --version)
    log_info "Node.js: $node_version"
    
    # Test Claude Flow
    if docker run --rm "$IMAGE_NAME:latest" which claude-flow >/dev/null; then
        log_success "Claude Flow disponible ✅"
    else
        log_error "Claude Flow non trouvé ❌"
        return 1
    fi
    
    # Test utilisateur
    local user=$(docker run --rm "$IMAGE_NAME:latest" whoami)
    if [[ "$user" == "claude" ]]; then
        log_success "Utilisateur sécurisé: $user ✅"
    else
        log_error "Utilisateur incorrect: $user ❌"
        return 1
    fi
}

# Nettoyage des images de test
cleanup_test_images() {
    log_info "🧹 Nettoyage des images de test..."
    
    docker rmi "$IMAGE_NAME:current-test" 2>/dev/null || true
    docker rmi "$IMAGE_NAME:nodejs20-test" 2>/dev/null || true
    docker rmi "$IMAGE_NAME:local-test" 2>/dev/null || true
    
    log_success "Nettoyage terminé"
}

# Rapport final
final_report() {
    echo ""
    echo "================================================="
    echo "🎯 RAPPORT DE CONSTRUCTION DOCKER"
    echo "================================================="
    echo ""
    
    if docker images | grep -q "$IMAGE_NAME.*latest"; then
        local image_size=$(docker images "$IMAGE_NAME:latest" --format "{{.Size}}")
        echo "✅ Image finale: $IMAGE_NAME:latest"
        echo "📦 Taille: $image_size"
        echo ""
        echo "🚀 Pour tester l'image:"
        echo "   docker run -it --rm -p 3000:3000 $IMAGE_NAME:latest"
        echo ""
        echo "🎯 Pour l'utiliser dans vos scripts:"
        echo "   docker build -t claude-flow-secure ."
        echo "   ./scripts/launch.sh"
    else
        echo "❌ Aucune image finale disponible"
        echo ""
        echo "🔧 Dépannage:"
        echo "   1. Vérifiez les logs ci-dessus"
        echo "   2. Testez manuellement: docker build -t test ."
        echo "   3. Vérifiez la version Docker: docker --version"
    fi
}

# Fonction principale
main() {
    echo "🤖 Build Docker Intelligent - Claude Flow Secure"
    echo "================================================"
    echo ""
    
    # Sauvegarde
    backup_dockerfile
    
    # Test des différentes approches
    log_info "🧪 Test des différentes approches de construction..."
    local best_approach=$(test_build_approaches)
    
    if [[ -n "$best_approach" ]]; then
        log_success "Meilleure approche trouvée: $best_approach"
        
        # Construction finale
        if final_build "$best_approach"; then
            # Validation
            if quick_validation; then
                log_success "🎉 Construction et validation réussies!"
            else
                log_warning "Construction réussie mais validation échouée"
            fi
        else
            log_error "Échec de la construction finale"
        fi
    else
        log_error "Aucune approche de construction réussie"
        restore_dockerfile
    fi
    
    # Nettoyage et rapport
    cleanup_test_images
    final_report
    
    # Nettoyer le backup si tout s'est bien passé
    if [[ "${1:-}" != "--keep-backup" ]]; then
        rm -f "$BACKUP_DOCKERFILE"
    fi
}

# Gestion des arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0 [--keep-backup]"
        echo ""
        echo "Construit intelligemment l'image Docker Claude Flow"
        echo "Teste plusieurs approches et choisit la meilleure"
        echo ""
        echo "Options:"
        echo "  --keep-backup    Garde le backup du Dockerfile original"
        echo "  --help, -h       Affiche cette aide"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac