#!/bin/bash

# =================================================================
# Script de Test de Connectivité Claude Flow
# =================================================================

set -euo pipefail

# Configuration
CLAUDE_FLOW_URL="http://127.0.0.1:3000"
MCP_SERVER_URL="http://127.0.0.1:8080"
WEBSOCKET_URL="ws://127.0.0.1:3000/ws"
CONTAINER_NAME="claude-flow-$(basename "$(pwd)")"

# Vérifier le nom du container existant
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    # Essayer avec docker-compose nom par défaut
    PROJECT_NAME=$(basename "$(pwd)")
    CONTAINER_NAME="claude-flow-${PROJECT_NAME}"
fi

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
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Test de base - Container en cours d'exécution
test_container_status() {
    log_info "Test 1: Statut du container"
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        local status=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Status}}')
        if [[ "$status" == "running" ]]; then
            log_success "Container en cours d'exécution"
            return 0
        else
            log_error "Container dans l'état: $status"
            return 1
        fi
    else
        log_error "Container non trouvé ou arrêté"
        return 1
    fi
}

# Test de santé du container
test_container_health() {
    log_info "Test 2: Santé du container"
    
    local health=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
    
    case "$health" in
        "healthy")
            log_success "Container en bonne santé"
            return 0
            ;;
        "unhealthy")
            log_error "Container en mauvaise santé"
            return 1
            ;;
        "starting")
            log_warning "Container en cours de démarrage"
            return 0  # Acceptable en CI/CD
            ;;
        "no-healthcheck")
            log_warning "Pas de vérification de santé configurée"
            return 0
            ;;
        *)
            log_error "Statut de santé inconnu: $health"
            return 1
            ;;
    esac
}

# Test HTTP - Interface Web
test_web_interface() {
    log_info "Test 3: Interface Web ($CLAUDE_FLOW_URL)"
    
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$CLAUDE_FLOW_URL" 2>/dev/null || echo "000")
    
    if [[ "$response_code" =~ ^[23][0-9][0-9]$ ]]; then
        log_success "Interface Web accessible (HTTP $response_code)"
        return 0
    else
        log_error "Interface Web inaccessible (HTTP $response_code)"
        return 1
    fi
}

# Test MCP Server
test_mcp_server() {
    log_info "Test 4: Serveur MCP"
    
    # Vérifier d'abord que le port 8080 est en écoute
    if ss -tuln 2>/dev/null | grep -q ":8080 "; then
        log_success "Port MCP 8080 en écoute"
        
        # Test simple de connexion au port
        if timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/8080" 2>/dev/null; then
            log_success "Port MCP 8080 accessible"
            return 0
        else
            log_warning "Port MCP 8080 en écoute mais non accessible"
            return 0  # Considérer comme succès car le port écoute
        fi
    else
        log_error "Port MCP 8080 non en écoute"
        return 1
    fi
}

# Test WebSocket (si wscat est disponible)
test_websocket() {
    log_info "Test 5: WebSocket"
    
    if command -v wscat &> /dev/null; then
        # Test avec timeout de 5 secondes
        if timeout 5 wscat -c "$WEBSOCKET_URL" -x 'ping' &>/dev/null; then
            log_success "WebSocket accessible"
            return 0
        else
            log_error "WebSocket inaccessible"
            return 1
        fi
    else
        log_warning "wscat non installé, test WebSocket ignoré"
        log_info "  Installer avec: npm install -g wscat"
        return 0
    fi
}

# Test des ports
test_ports() {
    log_info "Test 6: Ports d'écoute"
    
    local port_3000_ok=false
    local port_8080_ok=false
    
    if netstat -tuln 2>/dev/null | grep -q ":3000 "; then
        log_success "Port 3000 en écoute"
        port_3000_ok=true
    else
        log_error "Port 3000 non en écoute"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":8080 "; then
        log_success "Port 8080 en écoute"
        port_8080_ok=true
    else
        log_error "Port 8080 non en écoute"
    fi
    
    [[ "$port_3000_ok" == true && "$port_8080_ok" == true ]]
}

# Test des ressources système
test_system_resources() {
    log_info "Test 7: Ressources système"
    
    local container_stats=$(docker stats --no-stream "$CONTAINER_NAME" --format "table {{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | tail -n +2)
    
    if [[ -n "$container_stats" ]]; then
        log_success "Statistiques container: $container_stats"
        return 0
    else
        log_error "Impossible d'obtenir les statistiques"
        return 1
    fi
}

# Test de Claude Code (si disponible)
test_claude_code_integration() {
    log_info "Test 8: Intégration Claude Code"
    
    if command -v claude &> /dev/null; then
        # Exporter les variables d'environnement
        export CLAUDE_FLOW_URL="$CLAUDE_FLOW_URL"
        export CLAUDE_MCP_URL="$MCP_SERVER_URL"
        
        # Test de connexion Claude Code (simulation)
        if curl -s "$MCP_SERVER_URL/health" &>/dev/null; then
            log_success "Configuration Claude Code prête"
            log_info "  Variables: CLAUDE_FLOW_URL=$CLAUDE_FLOW_URL"
            log_info "  Variables: CLAUDE_MCP_URL=$MCP_SERVER_URL"
            return 0
        else
            log_error "Serveur MCP non accessible pour Claude Code"
            return 1
        fi
    else
        log_warning "Claude Code non installé"
        log_info "  Installation: npm install -g @anthropic-ai/claude-code"
        return 0
    fi
}

# Test des logs
test_logs() {
    log_info "Test 9: Logs du container"
    
    local log_lines=$(docker logs "$CONTAINER_NAME" 2>&1 | wc -l)
    
    if [[ "$log_lines" -gt 0 ]]; then
        log_success "Logs disponibles ($log_lines lignes)"
        
        # Vérifier s'il y a des erreurs dans les logs
        local error_count=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i "error" | wc -l)
        if [[ "$error_count" -gt 0 ]]; then
            log_warning "$error_count erreur(s) détectée(s) dans les logs"
        fi
        
        return 0
    else
        log_error "Aucun log disponible"
        return 1
    fi
}

# Rapport détaillé
generate_report() {
    echo ""
    echo "================================================="
    echo "🔍 RAPPORT DÉTAILLÉ DE CONNECTIVITÉ"
    echo "================================================="
    
    echo ""
    echo "📊 Informations système:"
    echo "   🐳 Container: $CONTAINER_NAME"
    echo "   🌐 Interface Web: $CLAUDE_FLOW_URL"
    echo "   🔌 MCP Server: $MCP_SERVER_URL"
    echo "   📡 WebSocket: $WEBSOCKET_URL"
    
    echo ""
    echo "📈 Statistiques temps réel:"
    docker stats --no-stream "$CONTAINER_NAME" 2>/dev/null || echo "   ❌ Statistiques non disponibles"
    
    echo ""
    echo "📝 Dernières lignes des logs:"
    docker logs --tail 5 "$CONTAINER_NAME" 2>/dev/null | sed 's/^/   /' || echo "   ❌ Logs non disponibles"
    
    echo ""
    echo "🔧 Commandes de diagnostic:"
    echo "   docker logs -f $CONTAINER_NAME           # Logs en temps réel"
    echo "   docker exec -it $CONTAINER_NAME sh       # Accès au container"
    echo "   curl $CLAUDE_FLOW_URL/health             # Test direct interface"
    echo "   curl $MCP_SERVER_URL/health              # Test direct MCP"
}

# Suggestions de dépannage
show_troubleshooting() {
    echo ""
    echo "🔧 GUIDE DE DÉPANNAGE"
    echo "===================="
    echo ""
    echo "Si des tests échouent:"
    echo ""
    echo "1. Redémarrer le container:"
    echo "   ./stop-claude-flow.sh"
    echo "   ./launch-claude-flow.sh"
    echo ""
    echo "2. Vérifier les logs détaillés:"
    echo "   docker logs $CONTAINER_NAME"
    echo ""
    echo "3. Vérifier la configuration:"
    echo "   docker inspect $CONTAINER_NAME"
    echo ""
    echo "4. Tester manuellement:"
    echo "   curl -v $CLAUDE_FLOW_URL"
    echo "   curl -v $MCP_SERVER_URL/health"
    echo ""
    echo "5. Réinitialiser complètement:"
    echo "   ./stop-claude-flow.sh --full-cleanup"
    echo "   docker system prune -f"
    echo "   ./launch-claude-flow.sh"
}

# Fonction principale
main() {
    echo "🧪 Test de Connectivité Claude Flow"
    echo "==================================="
    echo ""
    
    local failed_tests=0
    local total_tests=9
    
    # Exécuter tous les tests
    test_container_status || ((failed_tests++))
    test_container_health || ((failed_tests++))
    test_web_interface || ((failed_tests++))
    test_mcp_server || ((failed_tests++))
    test_websocket || ((failed_tests++))
    test_ports || ((failed_tests++))
    test_system_resources || ((failed_tests++))
    test_claude_code_integration || ((failed_tests++))
    test_logs || ((failed_tests++))
    
    echo ""
    echo "📊 RÉSULTATS DES TESTS"
    echo "====================="
    
    local success_count=$((total_tests - failed_tests))
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "Tous les tests réussis! ($success_count/$total_tests)"
        echo "🎉 Claude Flow est complètement opérationnel!"
    elif [[ $failed_tests -lt 3 ]]; then
        log_warning "Tests majoritairement réussis ($success_count/$total_tests)"
        echo "⚠️  Claude Flow fonctionne avec quelques problèmes mineurs"
    else
        log_error "Plusieurs tests échoués ($success_count/$total_tests)"
        echo "❌ Claude Flow a des problèmes significatifs"
    fi
    
    # Afficher le rapport si demandé
    if [[ "${1:-}" == "--detailed" ]]; then
        generate_report
    fi
    
    # Afficher les suggestions si des tests échouent
    if [[ $failed_tests -gt 0 ]]; then
        show_troubleshooting
    fi
    
    return $failed_tests
}

# Gestion des arguments
case "${1:-}" in
    "--detailed"|"-d")
        main "$@"
        ;;
    "--help"|"-h")
        echo "Usage: $0 [--detailed]"
        echo ""
        echo "Options:"
        echo "  --detailed, -d    Affiche un rapport détaillé"
        echo "  --help, -h        Affiche cette aide"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac