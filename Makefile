# Makefile pour Claude Flow Sécurisé
# Version: 1.1.0
# Compatible avec tous les scripts créés

.PHONY: help start stop test clean logs shell status backup install build quick-start restart
.DEFAULT_GOAL := help

# Variables
PROJECT_NAME := $(shell basename $(CURDIR))
CONTAINER_NAME := claude-flow-$(PROJECT_NAME)
IMAGE_NAME := claude-flow-secure

# Couleurs pour l'affichage
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

help: ## 📖 Affiche l'aide avec toutes les commandes disponibles
	@echo ""
	@echo "$(BLUE)🐳 Claude Flow Secure - Commandes Makefile$(RESET)"
	@echo "$(BLUE)===============================================$(RESET)"
	@echo ""
	@echo "$(GREEN)🚀 COMMANDES PRINCIPALES$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep "🚀\|▶️\|⏹️\|🧪" | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)  %-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)🔧 GESTION ET MAINTENANCE$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep "🔧\|📊\|🧹\|💾\|🔨" | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)  %-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)🔍 TESTS ET VALIDATION$(RESET)"  
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep "🔍\|✅\|🧪" | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)  %-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)📚 Exemples d'utilisation :$(RESET)"
	@echo "  $(GREEN)make quick-start$(RESET)     # Démarrage rapide avec tests"
	@echo "  $(GREEN)make test-full$(RESET)       # Suite complète de tests"
	@echo "  $(GREEN)make status$(RESET)          # Statut détaillé du système"
	@echo ""

# =============================================================================
# COMMANDES PRINCIPALES
# =============================================================================

quick-start: ## 🚀 Démarrage rapide avec validation automatique
	@echo "$(BLUE)🚀 Démarrage rapide Claude Flow...$(RESET)"
	@chmod +x scripts/*.sh 2>/dev/null || true
	@if [ -f scripts/test-docker-build.sh ]; then \
		echo "$(YELLOW)🧪 Test de construction rapide...$(RESET)"; \
		./scripts/test-docker-build.sh || echo "$(RED)⚠️  Tests échoués, continuons quand même$(RESET)"; \
	fi
	@$(MAKE) start
	@sleep 5
	@echo "$(GREEN)✅ Claude Flow démarré!$(RESET)"
	@echo "$(BLUE)🌐 Interface: http://127.0.0.1:3000/console$(RESET)"

start: ## ▶️ Démarre Claude Flow avec backup automatique
	@echo "$(BLUE)▶️  Démarrage de Claude Flow...$(RESET)"
	@chmod +x scripts/*.sh 2>/dev/null || true
	@if [ -f scripts/launch.sh ]; then \
		./scripts/launch.sh; \
	elif [ -f docker-compose.yml ]; then \
		export UID=$$(id -u) && export GID=$$(id -g) && docker-compose up -d; \
	else \
		echo "$(RED)❌ Aucun script de lancement trouvé$(RESET)"; \
		exit 1; \
	fi

stop: ## ⏹️ Arrête Claude Flow avec sauvegarde des logs
	@echo "$(BLUE)⏹️  Arrêt de Claude Flow...$(RESET)"
	@if [ -f scripts/stop.sh ]; then \
		./scripts/stop.sh; \
	elif [ -f docker-compose.yml ]; then \
		docker-compose down; \
	else \
		docker stop $(CONTAINER_NAME) 2>/dev/null || true; \
		docker rm $(CONTAINER_NAME) 2>/dev/null || true; \
	fi
	@echo "$(GREEN)✅ Arrêt terminé$(RESET)"

restart: ## 🔄 Redémarre Claude Flow (stop + start)
	@echo "$(BLUE)🔄 Redémarrage de Claude Flow...$(RESET)"
	@$(MAKE) stop
	@sleep 2
	@$(MAKE) start

# =============================================================================
# TESTS ET VALIDATION
# =============================================================================

test: ## 🧪 Tests de connectivité standard
	@echo "$(BLUE)🧪 Tests de connectivité...$(RESET)"
	@if [ -f scripts/test-connectivity.sh ]; then \
		./scripts/test-connectivity.sh; \
	else \
		echo "$(YELLOW)⚠️  Script de test non trouvé, test manuel...$(RESET)"; \
		curl -f http://127.0.0.1:3000/health 2>/dev/null && echo "$(GREEN)✅ Interface Web OK$(RESET)" || echo "$(RED)❌ Interface Web KO$(RESET)"; \
		curl -f http://127.0.0.1:8080/health 2>/dev/null && echo "$(GREEN)✅ MCP Server OK$(RESET)" || echo "$(RED)❌ MCP Server KO$(RESET)"; \
	fi

test-detailed: ## 🔍 Tests détaillés avec rapport complet
	@echo "$(BLUE)🔍 Tests détaillés...$(RESET)"
	@if [ -f scripts/test-connectivity.sh ]; then \
		./scripts/test-connectivity.sh --detailed; \
	else \
		$(MAKE) test; \
	fi

test-build: ## 🔨 Test de construction Docker complet
	@echo "$(BLUE)🔨 Test de construction Docker...$(RESET)"
	@if [ -f scripts/test-docker-build.sh ]; then \
		./scripts/test-docker-build.sh; \
	else \
		echo "$(YELLOW)⚠️  Script de test build non trouvé, construction simple...$(RESET)"; \
		docker build -t $(IMAGE_NAME):test . && echo "$(GREEN)✅ Construction réussie$(RESET)" || echo "$(RED)❌ Construction échouée$(RESET)"; \
	fi

test-full: ## ✅ Suite complète de tous les tests
	@echo "$(BLUE)✅ Suite complète de tests...$(RESET)"
	@$(MAKE) test-build
	@$(MAKE) test-detailed
	@$(MAKE) status
	@echo "$(GREEN)🎉 Tous les tests terminés!$(RESET)"

# =============================================================================
# BUILD ET INSTALLATION  
# =============================================================================

build: ## 🔨 Construction de l'image Docker
	@echo "$(BLUE)🔨 Construction de l'image Docker...$(RESET)"
	@if [ -f scripts/smart-docker-build.sh ]; then \
		./scripts/smart-docker-build.sh; \
	else \
		docker build -t $(IMAGE_NAME):latest .; \
	fi
	@echo "$(GREEN)✅ Image construite: $(IMAGE_NAME):latest$(RESET)"

build-no-cache: ## 🔨 Construction sans cache Docker
	@echo "$(BLUE)🔨 Construction sans cache...$(RESET)"
	@docker build --no-cache -t $(IMAGE_NAME):latest .
	@echo "$(GREEN)✅ Construction terminée$(RESET)"

install: ## 📦 Installation des dépendances et configuration
	@echo "$(BLUE)📦 Installation et configuration...$(RESET)"
	@chmod +x scripts/*.sh 2>/dev/null || true
	@mkdir -p /tmp/claude-logs/{claude-flow,security,backups,final-logs} 2>/dev/null || true
	@mkdir -p .claude 2>/dev/null || true
	@echo "$(GREEN)✅ Installation terminée$(RESET)"

# =============================================================================
# MONITORING ET GESTION
# =============================================================================

status: ## 📊 Affiche le statut complet du système
	@echo "$(BLUE)📊 Statut du système Claude Flow$(RESET)"
	@echo "$(BLUE)================================$(RESET)"
	@echo ""
	@echo "$(GREEN)🐳 Containers Docker:$(RESET)"
	@docker ps | grep claude-flow || echo "$(YELLOW)  Aucun container Claude Flow en cours$(RESET)"
	@echo ""
	@echo "$(GREEN)🌐 Ports en écoute:$(RESET)"
	@netstat -tuln 2>/dev/null | grep -E ":(3000|8080) " | sed 's/^/  /' || echo "$(YELLOW)  Ports 3000/8080 libres$(RESET)"
	@echo ""
	@echo "$(GREEN)💾 Espace disque (logs):$(RESET)"
	@du -sh /tmp/claude-logs/ 2>/dev/null | sed 's/^/  /' || echo "$(YELLOW)  Répertoire logs non trouvé$(RESET)"
	@echo ""
	@echo "$(GREEN)🔍 Images Docker:$(RESET)"
	@docker images | grep claude-flow | sed 's/^/  /' || echo "$(YELLOW)  Aucune image Claude Flow$(RESET)"

logs: ## 📋 Affiche les logs en temps réel
	@echo "$(BLUE)📋 Logs en temps réel...$(RESET)"
	@if docker ps | grep -q $(CONTAINER_NAME); then \
		docker logs -f $(CONTAINER_NAME); \
	else \
		echo "$(RED)❌ Container $(CONTAINER_NAME) non trouvé$(RESET)"; \
		echo "$(YELLOW)💡 Containers disponibles:$(RESET)"; \
		docker ps | grep claude-flow || echo "$(YELLOW)  Aucun container Claude Flow$(RESET)"; \
	fi

logs-tail: ## 📋 Affiche les derniers logs (50 lignes)
	@echo "$(BLUE)📋 Derniers logs...$(RESET)"
	@if docker ps | grep -q $(CONTAINER_NAME); then \
		docker logs --tail 50 $(CONTAINER_NAME); \
	else \
		echo "$(RED)❌ Container $(CONTAINER_NAME) non trouvé$(RESET)"; \
	fi

shell: ## 🖥️ Accès shell au container
	@echo "$(BLUE)🖥️  Accès shell...$(RESET)"
	@if docker ps | grep -q $(CONTAINER_NAME); then \
		docker exec -it $(CONTAINER_NAME) sh; \
	else \
		echo "$(RED)❌ Container $(CONTAINER_NAME) non trouvé ou arrêté$(RESET)"; \
		echo "$(YELLOW)💡 Démarrez d'abord avec: make start$(RESET)"; \
	fi

# =============================================================================
# SAUVEGARDE ET NETTOYAGE
# =============================================================================

backup: ## 💾 Sauvegarde du projet
	@echo "$(BLUE)💾 Sauvegarde du projet...$(RESET)"
	@mkdir -p /tmp/claude-logs/backups 2>/dev/null || true
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S) && \
	tar -czf "/tmp/claude-logs/backups/backup-$$TIMESTAMP.tar.gz" \
		--exclude='.git' --exclude='node_modules' --exclude='.claude' \
		--exclude='/tmp' --exclude='*.log' . && \
	echo "$(GREEN)✅ Backup sauvé: /tmp/claude-logs/backups/backup-$$TIMESTAMP.tar.gz$(RESET)"
	@if [ -d .git ]; then \
		git add . 2>/dev/null && git commit -m "Auto-backup $$(date)" 2>/dev/null || true; \
		echo "$(GREEN)✅ Backup Git effectué$(RESET)"; \
	fi

clean: ## 🧹 Nettoyage standard (containers arrêtés)
	@echo "$(BLUE)🧹 Nettoyage standard...$(RESET)"
	@docker container prune -f 2>/dev/null || true
	@echo "$(GREEN)✅ Nettoyage terminé$(RESET)"

clean-full: ## 🧹 Nettoyage complet (images, volumes, réseaux)
	@echo "$(BLUE)🧹 Nettoyage complet...$(RESET)"
	@if [ -f scripts/stop.sh ]; then \
		./scripts/stop.sh --full-cleanup; \
	else \
		$(MAKE) stop; \
		docker system prune -f 2>/dev/null || true; \
		docker volume prune -f 2>/dev/null || true; \
	fi
	@echo "$(GREEN)✅ Nettoyage complet terminé$(RESET)"

clean-logs: ## 🧹 Nettoyage des logs anciens (>7 jours)
	@echo "$(BLUE)🧹 Nettoyage des logs anciens...$(RESET)"
	@find /tmp/claude-logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
	@find /tmp/claude-logs/backups/ -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true
	@echo "$(GREEN)✅ Logs anciens nettoyés$(RESET)"

# =============================================================================
# COMMANDES DOCKER COMPOSE
# =============================================================================

compose-up: ## 🐙 Démarrage avec Docker Compose
	@echo "$(BLUE)🐙 Démarrage Docker Compose...$(RESET)"
	@if [ -f docker-compose.yml ]; then \
		export UID=$$(id -u) && export GID=$$(id -g) && docker-compose up -d; \
		echo "$(GREEN)✅ Services démarrés avec Docker Compose$(RESET)"; \
	else \
		echo "$(RED)❌ Fichier docker-compose.yml non trouvé$(RESET)"; \
	fi

compose-down: ## 🐙 Arrêt avec Docker Compose  
	@echo "$(BLUE)🐙 Arrêt Docker Compose...$(RESET)"
	@if [ -f docker-compose.yml ]; then \
		docker-compose down; \
		echo "$(GREEN)✅ Services arrêtés$(RESET)"; \
	else \
		echo "$(RED)❌ Fichier docker-compose.yml non trouvé$(RESET)"; \
	fi

compose-logs: ## 🐙 Logs Docker Compose
	@if [ -f docker-compose.yml ]; then \
		docker-compose logs -f; \
	else \
		echo "$(RED)❌ Fichier docker-compose.yml non trouvé$(RESET)"; \
	fi

# =============================================================================
# COMMANDES UTILITAIRES
# =============================================================================

health: ## 🏥 Vérification de santé des services
	@echo "$(BLUE)🏥 Vérification de santé...$(RESET)"
	@echo "$(GREEN)Interface Web:$(RESET)"
	@curl -f http://127.0.0.1:3000/health 2>/dev/null && echo "$(GREEN)  ✅ OK$(RESET)" || echo "$(RED)  ❌ KO$(RESET)"
	@echo "$(GREEN)MCP Server:$(RESET)"
	@curl -f http://127.0.0.1:8080/health 2>/dev/null && echo "$(GREEN)  ✅ OK$(RESET)" || echo "$(RED)  ❌ KO$(RESET)"

urls: ## 🌐 Affiche les URLs d'accès
	@echo "$(BLUE)🌐 URLs d'accès Claude Flow$(RESET)"
	@echo "$(BLUE)===========================$(RESET)"
	@echo "$(GREEN)Interface Web:$(RESET)    http://127.0.0.1:3000/console"
	@echo "$(GREEN)API Health:$(RESET)       http://127.0.0.1:3000/health"
	@echo "$(GREEN)MCP Server:$(RESET)       http://127.0.0.1:8080"
	@echo "$(GREEN)MCP Health:$(RESET)       http://127.0.0.1:8080/health"
	@echo "$(GREEN)WebSocket:$(RESET)        ws://127.0.0.1:3000/ws"

config-claude: ## ⚙️ Affiche la configuration Claude Code
	@echo "$(BLUE)⚙️  Configuration Claude Code$(RESET)"
	@echo "$(BLUE)=============================$(RESET)"
	@if [ -f /tmp/claude-logs/claude-code-config.sh ]; then \
		echo "$(GREEN)Configuration automatique disponible:$(RESET)"; \
		echo "  source /tmp/claude-logs/claude-code-config.sh"; \
		echo ""; \
		cat /tmp/claude-logs/claude-code-config.sh | grep export | sed 's/^/  /'; \
	else \
		echo "$(YELLOW)Configuration manuelle:$(RESET)"; \
		echo '  export CLAUDE_FLOW_URL="http://127.0.0.1:3000"'; \
		echo '  export CLAUDE_MCP_URL="http://127.0.0.1:8080"'; \
	fi

version: ## 📌 Affiche les versions des composants
	@echo "$(BLUE)📌 Versions des composants$(RESET)"
	@echo "$(BLUE)=========================$(RESET)"
	@if docker ps | grep -q $(CONTAINER_NAME); then \
		echo "$(GREEN)Node.js:$(RESET)      $$(docker exec $(CONTAINER_NAME) node --version 2>/dev/null || echo 'N/A')"; \
		echo "$(GREEN)npm:$(RESET)          $$(docker exec $(CONTAINER_NAME) npm --version 2>/dev/null || echo 'N/A')"; \
		echo "$(GREEN)Claude Flow:$(RESET)   $$(docker exec $(CONTAINER_NAME) claude-flow --version 2>/dev/null || echo 'N/A')"; \
	else \
		echo "$(YELLOW)Container non démarré$(RESET)"; \
	fi
	@echo "$(GREEN)Docker:$(RESET)       $$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo 'N/A')"
	@if command -v docker-compose >/dev/null 2>&1; then \
		echo "$(GREEN)Docker Compose:$(RESET) $$(docker-compose --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo 'N/A')"; \
	fi