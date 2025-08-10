#!/bin/bash

# =================================================================
# Script d'Arrêt Sécurisé pour Claude Flow
# =================================================================

set -euo pipefail

# Configuration
PROJECT_NAME=$(basename "$(pwd)")
CONTAINER_NAME="claude-flow-${PROJECT_NAME}"
NETWORK_NAME="claude-network"
LOG_DIR="/tmp/claude-logs"

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

# Sauvegarder les logs avant arrêt
save_logs() {
    if docker ps | grep -q "$CONTAINER_NAME"; then
        log_info "Sauvegarde des logs..."
        mkdir -p "$LOG_DIR/final-logs"
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        
        # Sauvegarder les logs du container
        docker logs "$CONTAINER_NAME" > "$LOG_DIR/final-logs/container-logs-${TIMESTAMP}.log" 2>&1
        
        # Sauvegarder les statistiques
        docker stats --no-stream "$CONTAINER_NAME" > "$LOG_DIR/final-logs/stats-${TIMESTAMP}.txt" 2>/dev/null || true
        
        log_success "Logs sauvegardés dans $LOG_DIR/final-logs/"
    fi
}

# Arrêter le container proprement
stop_container() {
    if docker ps | grep -q "$CONTAINER_NAME"; then
        log_info "Arrêt du container Claude Flow..."
        
        # Arrêt gracieux (30 secondes)
        docker stop -t 30 "$CONTAINER_NAME" 2>/dev/null || {
            log_warning "Arrêt gracieux échoué, forçage de l'arrêt..."
            docker kill "$CONTAINER_NAME" 2>/dev/null || true
        }
        
        # Suppression du container
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        
        log_success "Container arrêté et supprimé"
    else
        log_warning "Aucun container en cours d'exécution"
    fi
}

# Nettoyer les ressources Docker
cleanup_resources() {
    log_info "Nettoyage des ressources..."
    
    # Nettoyer les containers orphelins
    docker container prune -f &>/dev/null || true
    
    # Nettoyer les volumes non utilisés (optionnel)
    if [[ "${1:-}" == "--full-cleanup" ]]; then
        log_info "Nettoyage complet des ressources Docker..."
        docker volume prune -f &>/dev/null || true
        docker image prune -f &>/dev/null || true
        
        # Supprimer le réseau si plus d'autres containers
        if ! docker network inspect "$NETWORK_NAME" -f '{{range .Containers}}{{.Name}}{{end}}' 2>/dev/null | grep -q .; then
            docker network rm "$NETWORK_NAME" 2>/dev/null || true
            log_success "Réseau $NETWORK_NAME supprimé"
        fi
    fi
    
    log_success "Nettoyage terminé"
}

# Afficher le rapport final
show_final_report() {
    log_success "=== Arrêt de Claude Flow Terminé ==="
    echo ""
    echo "📊 Rapport final:"
    echo "   📂 Logs sauvegardés: $LOG_DIR/final-logs/"
    echo "   🗑️  Container supprimé: $CONTAINER_NAME"
    echo "   🔒 Sécurité: Aucun processus en arrière-plan"
    echo ""
    echo "📚 Pour redémarrer:"
    echo "   ./launch-claude-flow.sh"
    echo ""
    
    # Vérifier qu'aucun processus Claude Flow ne tourne
    if pgrep -f "claude-flow" > /dev/null; then
        log_warning "⚠️  Processus Claude Flow détectés en arrière-plan"
        echo "   Utilisez: pkill -f 'claude-flow' pour les arrêter"
    else
        log_success "✅ Aucun processus Claude Flow en arrière-plan"
    fi
}

# Vérifier les ports libérés
check_ports() {
    log_info "Vérification de la libération des ports..."
    
    if netstat -tuln 2>/dev/null | grep -q ":3000 "; then
        log_warning "Port 3000 encore utilisé"
    else
        log_success "Port 3000 libéré"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":8080 "; then
        log_warning "Port 8080 encore utilisé"
    else
        log_success "Port 8080 libéré"
    fi
}

# Fonction principale
main() {
    echo "🛑 Arrêt Sécurisé de Claude Flow"
    echo "==============================="
    
    save_logs
    stop_container
    cleanup_resources "$@"
    check_ports
    show_final_report
}

# Gestion des arguments
case "${1:-}" in
    "--full-cleanup")
        log_warning "Mode nettoyage complet activé"
        main "$@"
        ;;
    "--help"|"-h")
        echo "Usage: $0 [--full-cleanup]"
        echo ""
        echo "Options:"
        echo "  --full-cleanup    Supprime aussi les volumes et images non utilisées"
        echo "  --help, -h        Affiche cette aide"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac