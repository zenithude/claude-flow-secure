#!/bin/bash

# =================================================================
# Script de Lancement Sécurisé pour Claude Flow
# =================================================================

set -euo pipefail

# Configuration
PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")
CONTAINER_NAME="claude-flow-${PROJECT_NAME}"
IMAGE_NAME="claude-flow-secure"
NETWORK_NAME="claude-network"
LOG_DIR="/tmp/claude-logs"

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
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

# Vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon n'est pas démarré"
        exit 1
    fi
    
    log_success "Prérequis validés"
}

# Construire l'image Docker si nécessaire
build_image() {
    if ! docker images | grep -q "$IMAGE_NAME"; then
        log_info "Construction de l'image Docker..."
        docker build -t "$IMAGE_NAME" .
        log_success "Image Docker construite"
    else
        log_info "Image Docker déjà présente"
    fi
}

# Créer le réseau Docker sécurisé
setup_network() {
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        log_info "Création du réseau Docker sécurisé..."
        docker network create "$NETWORK_NAME" \
            --driver bridge \
            --subnet=172.20.0.0/16 \
            --opt com.docker.network.bridge.enable_icc=false \
            --opt com.docker.network.bridge.enable_ip_masquerade=true
        log_success "Réseau créé: $NETWORK_NAME"
    fi
}

# Backup automatique du projet
backup_project() {
    log_info "Sauvegarde automatique..."
    
    # Créer répertoire de backup
    mkdir -p "$LOG_DIR/backups"
    
    # Backup avec timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_NAME="${PROJECT_NAME}_backup_${TIMESTAMP}"
    
    # Backup avec tar (plus rapide que cp)
    tar -czf "$LOG_DIR/backups/${BACKUP_NAME}.tar.gz" \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='.claude' \
        -C "$(dirname "$PROJECT_DIR")" \
        "$(basename "$PROJECT_DIR")"
    
    # Backup Git si repo
    if [[ -d .git ]]; then
        git add . 2>/dev/null || true
        git commit -m "Auto-backup avant Claude Flow - $TIMESTAMP" 2>/dev/null || true
        log_success "Backup Git créé"
    fi
    
    log_success "Backup sauvé: $LOG_DIR/backups/${BACKUP_NAME}.tar.gz"
}

# Nettoyer les containers existants
cleanup_existing() {
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_info "Nettoyage du container existant..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        log_success "Container nettoyé"
    fi
}

# Créer les répertoires de logs
setup_logs() {
    mkdir -p "$LOG_DIR"
    mkdir -p "$LOG_DIR/claude-flow"
    mkdir -p "$LOG_DIR/security"
    chmod 755 "$LOG_DIR"
}

# Lancer le container Claude Flow
launch_container() {
    log_info "Lancement du container Claude Flow..."
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        --user "$(id -u):$(id -g)" \
        --network "$NETWORK_NAME" \
        --ip 172.20.0.10 \
        -v "$PROJECT_DIR:/workspace:rw" \
        -v "$LOG_DIR/claude-flow:/logs:rw" \
        -v "$LOG_DIR/security:/var/run/claude:rw" \
        -p 127.0.0.1:3000:3000 \
        -p 127.0.0.1:8080:8080 \
        --memory="2g" \
        --cpus="2.0" \
        --restart=unless-stopped \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=100m \
        --tmpfs /var/tmp:rw,noexec,nosuid,size=100m \
        --cap-drop=ALL \
        --cap-add=CHOWN \
        --cap-add=SETGID \
        --cap-add=SETUID \
        --security-opt=no-new-privileges:true \
        --security-opt=seccomp=unconfined \
        -e "CLAUDE_FLOW_LOG_LEVEL=info" \
        -e "NODE_ENV=production" \
        "$IMAGE_NAME"
    
    log_success "Container lancé: $CONTAINER_NAME"
}

# Attendre que le service soit disponible
wait_for_service() {
    log_info "Attente de la disponibilité du service..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://127.0.0.1:3000/health &>/dev/null; then
            log_success "Service disponible!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "Service non disponible après $max_attempts tentatives"
    return 1
}

# Afficher les informations de connexion
show_connection_info() {
    log_success "=== Claude Flow Démarré Avec Succès ==="
    echo ""
    echo "🌐 Interface Web:     http://127.0.0.1:3000"
    echo "🔌 MCP Server:       http://127.0.0.1:8080"
    echo "📋 Container:        $CONTAINER_NAME"
    echo "📂 Logs:             $LOG_DIR"
    echo "🔒 Réseau:           $NETWORK_NAME (172.20.0.10)"
    echo ""
    echo "📚 Commandes utiles:"
    echo "   docker logs -f $CONTAINER_NAME    # Voir les logs"
    echo "   docker exec -it $CONTAINER_NAME sh # Accéder au container"
    echo "   ./stop-claude-flow.sh              # Arrêter le service"
    echo ""
}

# Configurer Claude Code pour le container
setup_claude_code_config() {
    log_info "Configuration de Claude Code..."
    
    # Créer le fichier de configuration pour Claude Code
    cat > "$LOG_DIR/claude-code-config.sh" << 'EOF'
#!/bin/bash
# Configuration Claude Code pour container

export CLAUDE_FLOW_URL="http://127.0.0.1:3000"
export CLAUDE_MCP_URL="http://127.0.0.1:8080"

echo "Variables Claude Code configurées:"
echo "CLAUDE_FLOW_URL=$CLAUDE_FLOW_URL"
echo "CLAUDE_MCP_URL=$CLAUDE_MCP_URL"
echo ""
echo "Pour utiliser avec Claude Code:"
echo "source $LOG_DIR/claude-code-config.sh"
echo "claude --mcp-url \$CLAUDE_MCP_URL"
EOF
    
    chmod +x "$LOG_DIR/claude-code-config.sh"
    log_success "Configuration Claude Code créée: $LOG_DIR/claude-code-config.sh"
}

# Fonction principale
main() {
    echo "🚀 Lancement Sécurisé de Claude Flow"
    echo "==================================="
    
    check_prerequisites
    setup_logs
    backup_project
    build_image
    setup_network
    cleanup_existing
    launch_container
    
    if wait_for_service; then
        setup_claude_code_config
        show_connection_info
    else
        log_error "Échec du démarrage du service"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
}

# Gestion des signaux pour un arrêt propre
trap 'log_warning "Arrêt en cours..."; docker stop "$CONTAINER_NAME" 2>/dev/null; exit 0' INT TERM

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi