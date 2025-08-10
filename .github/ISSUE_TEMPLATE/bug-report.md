---
name: 🐛 Rapport de Bug
about: Signaler un problème avec Claude Flow Secure
title: '[BUG] '
labels: ['bug', 'needs-triage']
assignees: ''
---

## 🐛 Description du Bug

Une description claire et concise du problème rencontré.

## 🔄 Étapes pour Reproduire

Étapes pour reproduire le comportement :
1. Aller à '...'
2. Cliquer sur '....'
3. Faire défiler jusqu'à '....'
4. Voir l'erreur

## ✅ Comportement Attendu

Une description claire et concise de ce qui devrait se passer.

## ❌ Comportement Actuel

Une description claire et concise de ce qui se passe réellement.

## 📸 Captures d'Écran

Si applicable, ajoutez des captures d'écran pour expliquer votre problème.

## 🖥️ Environnement

**Informations système :**
- OS: [ex. Ubuntu 22.04, macOS 13.0, Windows 11]
- Version Docker: [ex. 24.0.6]
- Version Claude Flow: [ex. v2.0.0]
- Version Claude Code: [ex. 1.0.72]

**Configuration Docker :**
- RAM allouée: [ex. 2GB]
- CPU alloués: [ex. 2 cores]
- Version Docker Compose: [si utilisé]

## 📋 Logs

<details>
<summary>Logs du Container</summary>

```
Coller ici la sortie de : docker logs claude-flow-[project-name]
```

</details>

<details>
<summary>Logs de Connectivité</summary>

```
Coller ici la sortie de : ./scripts/test-connectivity.sh --detailed
```

</details>

<details>
<summary>Logs Système</summary>

```
Coller ici toute information système pertinente
```

</details>

## 🔧 Commandes Exécutées

Listez les commandes exactes exécutées avant l'apparition du bug :

```bash
# Exemple :
./scripts/launch.sh
make test
curl http://127.0.0.1:3000/health
```

## 🩺 Tests de Diagnostic Effectués

- [ ] `./scripts/test-connectivity.sh` exécuté
- [ ] `docker logs` vérifiés
- [ ] `make status` vérifié
- [ ] Redémarrage du container testé
- [ ] Ports 3000/8080 vérifiés libres
- [ ] Permissions Docker vérifiées

## 🔒 Impact Sécurité

- [ ] Ce bug pourrait-il compromettre la sécurité du container ?
- [ ] Ce bug expose-t-il des données sensibles ?
- [ ] Ce bug permet-il un accès non autorisé ?

Si oui à l'une de ces questions, merci de nous contacter en privé.

## 💡 Solutions Tentées

Décrivez les solutions que vous avez déjà essayées :

- [ ] Redémarrage du container
- [ ] Reconstruction de l'image Docker
- [ ] Nettoyage complet (`make clean`)
- [ ] Vérification de la configuration
- [ ] Autre : [préciser]

## 📝 Contexte Additionnel

Ajoutez ici tout autre contexte utile pour comprendre le problème.

## 🎯 Priorité

- [ ] Critique (empêche complètement l'utilisation)
- [ ] Élevée (impact majeur sur l'utilisation)
- [ ] Moyenne (gêne mais contournement possible)
- [ ] Faible (amélioration souhaitée)

---

### 📚 Aide Rapide

Avant de soumettre, avez-vous :
- [ ] Lu la [documentation de dépannage](../docs/TROUBLESHOOTING.md) ?
- [ ] Vérifié les [issues existantes](../../issues) ?
- [ ] Testé avec la dernière version ?
- [ ] Fourni toutes les informations demandées ?