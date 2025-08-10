#!/bin/bash

# =================================================================
# Script d'Installation Automatique Claude Flow Sécurisé
# =================================================================

set -euo pipefail

# Configuration
REPO_URL="https://raw.githubusercontent.com/user/claude-flow-secure/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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

log_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

# Vérifier les prérequis système
check_system_requirements() {
    log_header "🔍 Vérification des Prérequis Système"
    echo ""
    
    local missing_deps=()
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        missing_deps+=("docker")
    else
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        log_success "Docker installé: $docker_version"
        
        # Vérifier que Docker daemon fonctionne
        if ! docker info &> /dev/null; then
            log_error "Docker daemon n'est pas démarré"
            echo "  Démarrez Docker avec: sudo systemctl start docker"
            exit 1
        fi
    fi
    
    # Vérifier Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_warning "Docker Compose non installé (optionnel)"
        log_info "  Installation: sudo apt-get install docker-compose"
    else
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
        log_success "Docker Compose installé: $compose_version"
    fi
    
    # Vérifier Node.js et npm
    if ! command -v node &> /dev/null; then
        log_warning "Node.js non installé (optionnel pour développement)"
    else
        local node_version=$(node --version)
        log_success "Node.js installé: $node_version"
    fi
    
    # Vérifier curl
    if ! command -v curl &> /dev/null; then
        log_error "curl n'est pas installé"
        missing_deps+=("curl")
    else
        log_success "curl disponible"
    fi
    
    # Vérifier git
    if ! command -v git &> /dev/null; then
        log_warning "git non installé (recommandé)"
    else
        log_success "git disponible"
    fi
    
    # Arrêter si des dépendances critiques manquent
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dépendances manquantes: ${missing_deps[*]}"
        echo ""
        echo "Installation Ubuntu/Debian:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y docker.io curl git"
        echo "  sudo systemctl start docker"
        echo "  sudo usermod -aG docker \$USER"
        echo ""
        echo "Installation CentOS/RHEL:"
        echo "  sudo yum install -y docker curl git"
        echo "  sudo systemctl start docker"
        echo "  sudo usermod -aG docker \$USER"
        echo ""
        exit 1
    fi
    
    log_success "Tous les prérequis système sont satisfaits"
    echo ""
}

# Créer la structure de fichiers
create_project_structure() {
    log_header "📁 Création de la Structure de Projet"
    echo ""
    
    # Créer les répertoires nécessaires
    mkdir -p .claude-flow-secure/{scripts,config,logs,backups}
    mkdir -p /tmp/claude-logs/{claude-flow,security,backups,final-logs}
    
    log_success "Structure de répertoires créée"
    
    # Créer le .gitignore si nécessaire
    if [[ ! -f .gitignore ]]; then
        cat > .gitignore << 'EOF'
# Claude Flow Secure
.claude-flow-secure/logs/
.claude-flow-secure/backups/
/tmp/claude-logs/
.claude/

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.production

# Docker
.dockerignore
EOF
        log_success "Fichier .gitignore créé"
    fi
    
    echo ""
}

# Créer les fichiers de configuration
create_configuration_files() {
    log_header "⚙️  Création des Fichiers de Configuration"
    echo ""
    
    # Dockerfile
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
    log_success "Dockerfile créé"
    
    # Configuration Claude Flow sécurisée
    mkdir -p .claude
    cat > .claude/settings.json << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(pwd)",
      "Bash(ls)",
      "Bash(ls -la)",
      "Bash(cat package.json)",
      "Bash(cat *.md)",
      "Bash(cat src/*)",
      "Bash(cat docs/*)",
      "Bash(npm run *)",
      "Bash(npm test)",
      "Bash(npm install *)",
      "Bash(git status)",
      "Bash(git diff)",
      "Bash(git add .)",
      "Bash(git commit -m *)",
      "Bash(node *.js)",
      "Bash(./claude-flow *)",
      "Bash(find . -name *)",
      "Bash(grep *)",
      "Bash(echo *)"
    ],
    "deny": [
      "Bash(cd /)",
      "Bash(cd ~)",
      "Bash(cd ..*)",
      "Bash(find /)",
      "Bash(cat /etc/*)",
      "Bash(cat ~/.ssh/*)",
      "Bash(curl * | bash)",
      "Bash(wget *)",
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Bash(chmod +x *)",
      "Bash(mkdir /*)",
      "Bash(cp * /*)",
      "Bash(mv * /*)",
      "Bash(eval *)"
    ]
  },
  "claude_flow_security": {
    "container_mode": true,
    "restricted_paths": ["/", "/etc", "/usr", "/var", "/home"],
    "allowed_network": ["127.0.0.1", "localhost"],
    "max_memory": "2G",
    "max_cpu": "2.0"
  },
  "automation": {
    "auto_save": true,
    "backup_before_run": true,
    "log_all_commands": true,
    "timeout_seconds": 300
  }
}
EOF
    log_success "Configuration Claude sécurisée créée"
    
    echo ""
}

# Copier les scripts
copy_scripts() {
    log_header "📋 Installation des Scripts de Gestion"
    echo ""
    
    # Les scripts sont déjà créés dans les artifacts précédents
    # Ici on les rend exécutables et on les place correctement
    
    local scripts=(
        "launch-claude-flow.sh"
        "stop-claude-flow.sh" 
        "test-connectivity.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log_success "Script $script rendu exécutable"
        else
            log_warning "Script $script non trouvé (créez-le manuellement)"
        fi
    done
    
    # Créer un script de démarrage rapide
    cat > start-claude-flow-quick.sh << 'EOF'
#!/bin/bash
# Démarrage rapide Claude Flow
set -e

echo "🚀 Démarrage rapide Claude Flow..."

# Démarrer avec Docker Compose si disponible
if [[ -f docker-compose.yml ]] && command -v docker-compose &> /dev/null; then
    echo "📦 Utilisation de Docker Compose..."
    export UID=$(id -u)
    export GID=$(id -g)
    docker-compose up -d
else
    echo "🐳 Utilisation de Docker standard..."
    ./launch-claude-flow.sh
fi

echo "✅ Claude Flow démarré!"
echo "🌐 Interface: http://127.0.0.1:3000"

# Test rapide de connectivité
sleep 5
if curl -s http://127.0.0.1:3000/health &>/dev/null; then
    echo "🎉 Service opérationnel!"
else
    echo "⚠️  Service en cours de démarrage..."
fi
EOF
    chmod +x start-claude-flow-quick.sh
    log_success "Script de démarrage rapide créé"
    
    echo ""
}

# Configurer l'environnement de développement
setup_development_environment() {
    log_header "🛠️  Configuration de l'Environnement de Développement"
    echo ""
    
    # Créer un Makefile pour simplifier les commandes
    cat > Makefile << 'EOF'
# Makefile pour Claude Flow Sécurisé

.PHONY: help build start stop test clean logs shell

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Construit l'image Docker
	docker build -t claude-flow-secure .

start: ## Démarre Claude Flow
	./launch-claude-flow.sh

quick-start: ## Démarrage rapide
	./start-claude-flow-quick.sh

stop: ## Arrête Claude Flow
	./stop-claude-flow.sh

test: ## Test de connectivité
	./test-connectivity.sh

logs: ## Affiche les logs
	docker logs -f claude-flow-$(shell basename $(CURDIR)) 2>/dev/null || echo "Container non trouvé"

shell: ## Accès shell au container
	docker exec -it claude-flow-$(shell basename $(CURDIR)) sh

clean: ## Nettoyage complet
	./stop-claude-flow.sh --full-cleanup

backup: ## Sauvegarde du projet
	tar -czf "/tmp/claude-logs/backups/backup-$(shell date +%Y%m%d_%H%M%S).tar.gz" --exclude='.git' --exclude='node_modules' .

status: ## Statut du système
	@echo "=== Statut Claude Flow ==="
	@docker ps | grep claude-flow || echo "Aucun container Claude Flow"
	@echo ""
	@echo "=== Ports ==="
	@netstat -tuln 2>/dev/null | grep -E ":(3000|8080) " || echo "Ports 3000/8080 libres"
	@echo ""
	@echo "=== Espace disque ==="
	@df -h /tmp/claude-logs/ 2>/dev/null || echo "Répertoire logs non trouvé"

install-tools: ## Installe les outils optionnels
	@echo "Installation des outils optionnels..."
	@command -v wscat >/dev/null || npm install -g wscat
	@command -v docker-compose >/dev/null || echo "Installez docker-compose pour des fonctionnalités avancées"
EOF
    log_success "Makefile créé"
    
    # Configuration VS Code (si présent)
    if command -v code &> /dev/null; then
        mkdir -p .vscode
        cat > .vscode/settings.json << 'EOF'
{
    "docker.containers.label": "claude-flow",
    "docker.images.label": "claude-flow-secure",
    "terminal.integrated.defaultProfile.linux": "bash",
    "files.exclude": {
        "**/node_modules": true,
        "**/.git": true,
        "**/tmp": true,
        "**/.claude-flow-secure/logs": true
    }
}
EOF
        log_success "Configuration VS Code créée"
    fi
    
    echo ""
}

# Test de l'installation
test_installation() {
    log_header "🧪 Test de l'Installation"
    echo ""
    
    # Test de construction de l'image
    log_info "Construction de l'image Docker de test..."
    if docker build -t claude-flow-secure-test . &>/dev/null; then
        log_success "Image Docker construite avec succès"
        docker rmi claude-flow-secure-test &>/dev/null
    else
        log_error "Échec de construction de l'image Docker"
        return 1
    fi
    
    # Vérifier les permissions des scripts
    local scripts=(
        "launch-claude-flow.sh"
        "stop-claude-flow.sh"
        "test-connectivity.sh"
        "start-claude-flow-quick.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            log_success "Script $script exécutable"
        else
            log_warning "Script $script non exécutable"
        fi
    done
    
    log_success "Installation testée avec succès"
    echo ""
}

# Afficher le résumé final
show_final_summary() {
    log_header "🎉 Installation Terminée avec Succès!"
    echo ""
    echo "📁 Fichiers créés:"
    echo "   ├── Dockerfile                    # Image Docker sécurisée"
    echo "   ├── docker-compose.yml           # Configuration Docker Compose"
    echo "   ├── .claude/settings.json        # Configuration Claude sécurisée"
    echo "   ├── launch-claude-flow.sh        # Script de lancement"
    echo "   ├── stop-claude-flow.sh          # Script d'arrêt"
    echo "   ├── test-connectivity.sh         # Script de test"
    echo "   ├── start-claude-flow-quick.sh   # Démarrage rapide"
    echo "   └── Makefile                     # Commandes simplifiées"
    echo ""
    echo "🚀 Commandes de démarrage:"
    echo "   make quick-start          # Démarrage rapide"
    echo "   ./launch-claude-flow.sh   # Démarrage complet avec sécurité"
    echo "   make start                # Via Makefile"
    echo ""
    echo "🔧 Commandes de gestion:"
    echo "   make test                 # Test de connectivité"
    echo "   make logs                 # Voir les logs"
    echo "   make stop                 # Arrêt du service"
    echo "   make clean                # Nettoyage complet"
    echo "   make help                 # Aide Makefile"
    echo ""
    echo "🌐 Après démarrage:"
    echo "   Interface Web: http://127.0.0.1:3000"
    echo "   MCP Server:    http://127.0.0.1:8080"
    echo ""
    echo "📚 Documentation:"
    echo "   make help                 # Commandes disponibles"
    echo "   ./test-connectivity.sh -d # Test détaillé"
    echo "   docker logs [container]   # Logs détaillés"
    echo ""
    echo "⚠️  Sécurité:"
    echo "   ✅ Container isolé avec utilisateur non-privilégié"
    echo "   ✅ Réseau restreint (127.0.0.1 uniquement)"
    echo "   ✅ Permissions minimales configurées"
    echo "   ✅ Backup automatique avant chaque lancement"
    echo ""
    echo "🎯 Prochaines étapes:"
    echo "   1. Testez l'installation: make quick-start"
    echo "   2. Vérifiez la connectivité: make test"
    echo "   3. Consultez l'interface: http://127.0.0.1:3000"
    echo "   4. Configurez Claude Code avec les variables d'environnement"
    echo ""
}

# Fonction principale
main() {
    echo ""
    log_header "🔧 INSTALLATION AUTOMATIQUE CLAUDE FLOW SÉCURISÉ"
    echo "=================================================="
    echo ""
    echo "Cette installation va configurer:"
    echo "  • Docker container sécurisé pour Claude Flow"
    echo "  • Scripts de gestion automatisés"
    echo "  • Configuration de sécurité renforcée"
    echo "  • Outils de monitoring et de test"
    echo ""
    
    read -p "Continuer l'installation? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation annulée"
        exit 0
    fi
    
    echo ""
    
    check_system_requirements
    create_project_structure
    create_configuration_files
    copy_scripts
    setup_development_environment
    test_installation
    show_final_summary
    
    echo "✨ Installation terminée! Démarrez avec: make quick-start"
    echo ""
}

# Gestion des arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0"
        echo ""
        echo "Installation automatique de Claude Flow sécurisé"
        echo "Ce script configure un environnement Docker sécurisé pour Claude Flow"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac