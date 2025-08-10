# 🐳 Claude Flow Sécurisé - Docker Container

## 📋 Vue d'Ensemble

Cette solution fournit un environnement Docker sécurisé pour exécuter Claude Flow, permettant à Claude Code sur votre machine hôte d'interagir de manière sécurisée avec Claude Flow dans un container isolé.

### 🛡️ Fonctionnalités de Sécurité

- **Container Isolé** : Claude Flow s'exécute dans un environnement complètement isolé
- **Utilisateur Non-Privilégié** : Aucun accès root dans le container
- **Réseau Restreint** : Exposition uniquement sur localhost (127.0.0.1)
- **Permissions Minimales** : Seules les commandes nécessaires sont autorisées
- **Backup Automatique** : Sauvegarde avant chaque lancement
- **Monitoring** : Surveillance en temps réel et logs détaillés

## 🚀 Installation Rapide

### Méthode 1: Installation Automatique (Recommandée)

```bash
# Télécharger et exécuter le script d'installation
curl -sSL https://raw.githubusercontent.com/votre-repo/setup-claude-flow.sh | bash

# Ou manuellement:
wget https://raw.githubusercontent.com/votre-repo/setup-claude-flow.sh
chmod +x setup-claude-flow.sh
./setup-claude-flow.sh
```

### Méthode 2: Installation Manuelle

1. **Créer les fichiers** (utilisez les artifacts fournis):
   - `Dockerfile`
   - `docker-compose.yml`
   - `launch-claude-flow.sh`
   - `stop-claude-flow.sh`
   - `test-connectivity.sh`

2. **Rendre les scripts exécutables**:
   ```bash
   chmod +x *.sh
   ```

3. **Configurer l'environnement**:
   ```bash
   mkdir -p .claude /tmp/claude-logs
   # Copier la configuration .claude/settings.json
   ```

## 📦 Prérequis Système

- **Docker** (version 20.10+)
- **curl** (pour les tests de connectivité)
- **git** (recommandé pour les backups)
- **2GB RAM** disponible pour le container
- **Ports 3000 et 8080** libres

### Installation des Prérequis

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y docker.io curl git
sudo systemctl start docker
sudo usermod -aG docker $USER
```

**CentOS/RHEL:**
```bash
sudo yum install -y docker curl git
sudo systemctl start docker
sudo usermod -aG docker $USER
```

## 🎮 Utilisation

### Démarrage Rapide

```bash
# Méthode la plus simple
make quick-start

# Ou avec le script direct
./start-claude-flow-quick.sh

# Ou démarrage complet avec sécurité
./launch-claude-flow.sh
```

### Commandes Principales

| Commande | Description | Exemple |
|----------|-------------|---------|
| `make start` | Démarre Claude Flow | `make start` |
| `make stop` | Arrête Claude Flow | `make stop` |
| `make test` | Test de connectivité | `make test` |
| `make logs` | Affiche les logs | `make logs` |
| `make shell` | Accès au container | `make shell` |
| `make clean` | Nettoyage complet | `make clean` |

### Scripts Individuels

```bash
# Démarrage sécurisé avec backup automatique
./launch-claude-flow.sh

# Test de connectivité complet
./test-connectivity.sh

# Test détaillé avec rapport
./test-connectivity.sh --detailed

# Arrêt propre
./stop-claude-flow.sh

# Arrêt avec nettoyage complet
./stop-claude-flow.sh --full-cleanup
```

## 🔧 Configuration

### Configuration Claude Code

Après le démarrage de Claude Flow, configurez Claude Code sur votre machine hôte :

```bash
# Charger la configuration automatique
source /tmp/claude-logs/claude-code-config.sh

# Ou manuellement :
export CLAUDE_FLOW_URL="http://127.0.0.1:3000"
export CLAUDE_MCP_URL="http://127.0.0.1:8080"

# Tester la connexion
claude --mcp-url $CLAUDE_MCP_URL
```

### Configuration Personnalisée

Modifiez `.claude/settings.json` pour ajuster les permissions :

```json
{
  "permissions": {
    "allow": [
      "Bash(pwd)",
      "Bash(ls)",
      "Bash(cat package.json)",
      "Bash(npm run *)",
      "Bash(git status)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(curl * | bash)",
      "Bash(sudo *)"
    ]
  }
}
```

## 🌐 Accès aux Interfaces

Une fois démarré, Claude Flow est accessible via :

- **Interface Web** : http://127.0.0.1:3000
- **MCP Server** : http://127.0.0.1:8080
- **WebSocket** : ws://127.0.0.1:3000/ws
- **Health Check** : http://127.0.0.1:3000/health

## 📊 Monitoring et Logs

### Logs en Temps Réel

```bash
# Logs du container
docker logs -f claude-flow-$(basename $(pwd))

# Ou via Makefile
make logs

# Logs détaillés avec timestamp
docker logs -f --timestamps claude-flow-$(basename $(pwd))
```

### Monitoring des Ressources

```bash
# Statistiques du container
docker stats claude-flow-$(basename $(pwd))

# Statut complet
make status

# Test de santé
curl http://127.0.0.1:3000/health
```

### Localisation des Logs

- **Logs Container** : `/tmp/claude-logs/claude-flow/`
- **Logs Sécurité** : `/tmp/claude-logs/security/`
- **Backups** : `/tmp/claude-logs/backups/`
- **Logs Finaux** : `/tmp/claude-logs/final-logs/`

## 🔍 Dépannage

### Problèmes Courants

**1. Container ne démarre pas**
```bash
# Vérifier Docker
docker info

# Reconstruire l'image
docker build -t claude-flow-secure .

# Vérifier les logs de construction
docker build --no-cache -t claude-flow-secure .
```

**2. Ports déjà utilisés**
```bash
# Vérifier les ports
netstat -tuln | grep -E ":(3000|8080)"

# Arrêter les processus conflictuels
sudo lsof -ti:3000 | xargs kill -9
sudo lsof -ti:8080 | xargs kill -9
```

**3. Permissions insuffisantes**
```bash
# Vérifier l'utilisateur Docker
groups $USER

# Ajouter au groupe docker
sudo usermod -aG docker $USER
newgrp docker
```

**4. Interface Web inaccessible**
```bash
# Test direct
curl -v http://127.0.0.1:3000/health

# Vérifier le container
docker ps | grep claude-flow

# Redémarrer complet
./stop-claude-flow.sh --full-cleanup
./launch-claude-flow.sh
```

### Tests de Diagnostic

```bash
# Test complet automatisé
./test-connectivity.sh --detailed

# Test manuel étape par étape
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:8080/health
wscat -c ws://127.0.0.1:3000/ws
```

### Réinitialisation Complète

```bash
# Arrêt et nettoyage complet
./stop-claude-flow.sh --full-cleanup

# Nettoyage Docker global
docker system prune -f
docker volume prune -f

# Redémarrage propre
./launch-claude-flow.sh
```

## 🔒 Sécurité Avancée

### Configuration Firewall

```bash
# UFW (Ubuntu)
sudo ufw allow from 127.0.0.1 to any port 3000
sudo ufw allow from 127.0.0.1 to any port 8080

# iptables
sudo iptables -A INPUT -s 127.0.0.1 -p tcp --dport 3000 -j ACCEPT
sudo iptables -A INPUT -s 127.0.0.1 -p tcp --dport 8080 -j ACCEPT
```

### Audit et Surveillance

```bash
# Audit des commandes exécutées
sudo auditctl -w /tmp/claude-logs -p warx

# Surveillance réseau
sudo tcpdump -i docker0 port 3000

# Monitoring des processus
ps aux | grep claude-flow
```

### Sauvegarde et Récupération

```bash
# Backup manuel
make backup

# Backup automatique (dans crontab)
0 */6 * * * /path/to/project/make backup

# Restauration
tar -xzf /tmp/claude-logs/backups/backup-*.tar.gz
```

## 📚 Commandes Avancées

### Docker Compose

Si vous préférez utiliser Docker Compose :

```bash
# Variables d'environnement
export UID=$(id -u)
export GID=$(id -g)

# Démarrage
docker-compose up -d

# Arrêt
docker-compose down

# Logs
docker-compose logs -f
```

### Développement

```bash
# Accès shell pour debug
docker exec -it claude-flow-$(basename $(pwd)) sh

# Reconstruction forcée
docker build --no-cache -t claude-flow-secure .

# Mode développement avec volumes modifiables
docker run -it --rm \
  -v $(pwd):/workspace:rw \
  -p 127.0.0.1:3000:3000 \
  claude-flow-secure sh
```

## 📖 FAQ

**Q: Claude Code peut-il accéder aux fichiers de mon projet ?**  
R: Oui, mais seulement aux fichiers du répertoire courant grâce au montage de volume sécurisé.

**Q: Les données sont-elles persistantes ?**  
R: Les modifications dans le répertoire de travail sont persistantes. Les logs et configurations temporaires sont dans `/tmp/claude-logs/`.

**Q: Puis-je modifier les permissions ?**  
R: Oui, éditez `.claude/settings.json` et redémarrez le container.

**Q: Comment vérifier que la sécurité fonctionne ?**  
R: Utilisez `./test-connectivity.sh --detailed` pour un rapport complet.

**Q: Que faire si le container consomme trop de ressources ?**  
R: Modifiez les limites dans `docker-compose.yml` ou les scripts de lancement.

## 🤝 Contribution

Pour contribuer à cette solution :

1. Fork le repository
2. Créez une branche pour votre fonctionnalité
3. Testez avec `./test-connectivity.sh`
4. Soumettez une pull request

## 📄 Licence

Cette solution est distribuée sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## 🙏 Remerciements

- **Anthropic** pour Claude AI
- **Communauté Docker** pour les meilleures pratiques de sécurité
- **Contributeurs** qui ont testé et amélioré cette solution

---

**⚠️ Note de Sécurité** : Cette solution isole Claude Flow dans un container Docker sécurisé. Cependant, restez vigilant et ne l'utilisez que sur des projets de confiance. Effectuez toujours des backups avant utilisation.