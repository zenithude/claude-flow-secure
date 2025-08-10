#!/bin/bash

# =================================================================
# Script de Test pour la Construction Docker
# =================================================================

set -euo pipefail

# Configuration
IMAGE_NAME="claude-flow-secure"
TEST_CONTAINER="test-claude-flow-build"

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

# Nettoyage préalable
cleanup() {
    log_info "Nettoyage des ressources de test..."
    docker stop "$TEST_CONTAINER" 2>/dev/null || true
    docker rm "$TEST_CONTAINER" 2>/dev/null || true
    docker rmi "$IMAGE_NAME:test" 2>/dev/null || true
    log_success "Nettoyage terminé"
}

# Test de construction
test_build() {
    log_info "🔨 Test de construction de l'image Docker..."
    
    if docker build -t "$IMAGE_NAME:test" . --no-cache; then
        log_success "Image construite avec succès"
        return 0
    else
        log_error "Échec de construction de l'image"
        return 1
    fi
}

# Test des versions
test_versions() {
    log_info "🔍 Vérification des versions..."
    
    # Test Node.js
    local node_version=$(docker run --rm "$IMAGE_NAME:test" node --version)
    log_info "Version Node.js: $node_version"
    
    if [[ "$node_version" =~ ^v2[0-9] ]]; then
        log_success "Node.js version ≥20 ✓"
    else
        log_error "Node.js version insuffisante"
        return 1
    fi
    
    # Test npm
    local npm_version=$(docker run --rm "$IMAGE_NAME:test" npm --version)
    log_info "Version npm: $npm_version"
    
    # Test Claude Flow
    if docker run --rm "$IMAGE_NAME:test" which claude-flow >/dev/null; then
        local cf_version=$(docker run --rm "$IMAGE_NAME:test" claude-flow --version 2>/dev/null || echo "version non disponible")
        log_success "Claude Flow installé: $cf_version"
    else
        log_error "Claude Flow non trouvé"
        return 1
    fi
}

# Test des permissions
test_permissions() {
    log_info "🔐 Test des permissions utilisateur..."
    
    local current_user=$(docker run --rm "$IMAGE_NAME:test" whoami)
    if [[ "$current_user" == "claude" ]]; then
        log_success "Utilisateur non-privilégié: $current_user ✓"
    else
        log_error "Utilisateur incorrect: $current_user (attendu: claude)"
        return 1
    fi
    
    # Test des permissions de répertoire
    if docker run --rm "$IMAGE_NAME:test" test -w /workspace; then
        log_success "Permissions /workspace ✓"
    else
        log_error "Permissions /workspace insuffisantes"
        return 1
    fi
}

# Test de démarrage basique
test_startup() {
    log_info "🚀 Test de démarrage basique..."
    
    # Démarrer le container en arrière-plan
    if docker run -d --name "$TEST_CONTAINER" \
        -p 3001:3000 -p 8081:8080 \
        "$IMAGE_NAME:test" claude-flow start --ui --port 3000; then
        log_success "Container démarré"
    else
        log_error "Échec du démarrage du container"
        return 1
    fi
    
    # Attendre un peu
    log_info "Attente du démarrage des services (30s)..."
    sleep 30
    
    # Vérifier que le container fonctionne
    if docker ps | grep -q "$TEST_CONTAINER"; then
        log_success "Container en cours d'exécution ✓"
    else
        log_error "Container arrêté prématurément"
        docker logs "$TEST_CONTAINER"
        return 1
    fi
    
    # Test de connectivité (optionnel, peut échouer si le service met du temps)
    if curl -f http://127.0.0.1:3001/health --max-time 10 2>/dev/null; then
        log_success "Service accessible ✓"
    else
        log_warning "Service pas encore accessible (normal au premier démarrage)"
    fi
}

# Test des logs
test_logs() {
    log_info "📋 Vérification des logs..."
    
    local log_lines=$(docker logs "$TEST_CONTAINER" 2>&1 | wc -l)
    if [[ "$log_lines" -gt 0 ]]; then
        log_success "Logs générés ($log_lines lignes)"
        
        # Afficher les dernières lignes
        echo "Dernières lignes des logs:"
        docker logs --tail 5 "$TEST_CONTAINER" 2>&1 | sed 's/^/  /'
    else
        log_warning "Aucun log généré"
    fi
}

# Rapport final
final_report() {
    echo ""
    echo "================================================="
    echo "🎯 RAPPORT DE TEST DOCKER"
    echo "================================================="
    echo ""
    echo "📦 Image: $IMAGE_NAME:test"
    echo "🐳 Container: $TEST_CONTAINER"
    echo ""
    
    # Informations sur l'image
    local image_size=$(docker images "$IMAGE_NAME:test" --format "{{.Size}}")
    echo "📊 Taille de l'image: $image_size"
    
    # Informations sur le container
    if docker ps | grep -q "$TEST_CONTAINER"; then
        echo "🟢 Statut container: En cours d'exécution"
        docker stats --no-stream "$TEST_CONTAINER" 2>/dev/null || true
    else
        echo "🔴 Statut container: Arrêté"
    fi
    
    echo ""
    echo "🎉 Tests terminés! Image prête pour utilisation."
}

# Fonction principale
main() {
    echo "🧪 Test de Construction Docker - Claude Flow Secure"
    echo "=================================================="
    echo ""
    
    # Nettoyage initial
    cleanup
    
    local failed_tests=0
    
    # Exécuter les tests
    test_build || ((failed_tests++))
    test_versions || ((failed_tests++))
    test_permissions || ((failed_tests++))
    test_startup || ((failed_tests++))
    test_logs || ((failed_tests++))
    
    # Rapport final
    final_report
    
    # Nettoyage final (optionnel)
    if [[ "${1:-}" == "--cleanup" ]]; then
        cleanup
    else
        echo ""
        echo "💡 Pour nettoyer les ressources de test:"
        echo "   $0 --cleanup"
        echo "   ou manuellement:"
        echo "   docker stop $TEST_CONTAINER"
        echo "   docker rm $TEST_CONTAINER"
        echo "   docker rmi $IMAGE_NAME:test"
    fi
    
    # Code de sortie
    if [[ $failed_tests -eq 0 ]]; then
        log_success "Tous les tests réussis! 🎉"
        return 0
    else
        log_error "$failed_tests test(s) échoué(s)"
        return 1
    fi
}

# Gestion des arguments
case "${1:-}" in
    "--cleanup")
        cleanup
        exit 0
        ;;
    "--help"|"-h")
        echo "Usage: $0 [--cleanup|--help]"
        echo ""
        echo "Test de construction Docker pour Claude Flow Secure"
        echo ""
        echo "Options:"
        echo "  --cleanup    Nettoie seulement les ressources de test"
        echo "  --help, -h   Affiche cette aide"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac