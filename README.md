# Agrégation Mathématiques 2027 — Rituel quotidien

Site mobile : **https://feven-nit.github.io/agreg/**

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  MAC (toujours allumé)                                        │
│                                                              │
│  launchd 22h55 ─► generer.sh ─► claude -p                    │
│                          │                                   │
│                          ├─► écrit fiches/YYYY-MM-DD.md      │
│                          └─► git push vers GitHub            │
│                                                              │
│  launchd /60s ─► poller.sh                                   │
│                       │                                      │
│                       ├─► liste issues "agreg-redaction"     │
│                       ├─► pour chaque : claude -p valide     │
│                       ├─► gh issue comment (validation)      │
│                       └─► gh issue close                     │
└──────────────────────────────────────────────────────────────┘
          │ (git)                     │ (gh API)
          ▼                           ▲
┌──────────────────────────────────────────────────────────────┐
│  GITHUB                                                       │
│  • Repo public feven-NIT/agreg                                │
│  • GitHub Pages (docs/index.html)                             │
│  • Issues : rédactions et validations                         │
└──────────────────────────────────────────────────────────────┘
          │ (Pages)                   │ (API)
          ▼                           ▲
┌──────────────────────────────────────────────────────────────┐
│  iPhone                                                       │
│  • Ouvre feven-nit.github.io/agreg/                           │
│  • Voit la fiche du jour (correction masquée)                 │
│  • Tape sa rédaction                                          │
│  • Soumet → crée une issue GitHub                             │
│  • Attend validation (~60s poller + ~20s claude)              │
└──────────────────────────────────────────────────────────────┘
```

**Pas de clé API payante.** La validation tourne sur le Mac via `claude -p` (ta session Claude Code).

## Setup initial (1 fois)

### Sur le téléphone

1. Va sur **https://feven-nit.github.io/agreg/**
2. Crée un fine-grained PAT GitHub : https://github.com/settings/personal-access-tokens/new
   - Repository access : `agreg` uniquement
   - Permissions : **Contents: Read** + **Issues: Read and write**
3. Colle dans la page, valide
4. Ajoute à l'écran d'accueil (Safari → Partager → Sur l'écran d'accueil)

### Sur le Mac

Déjà fait. launchd actifs :

```bash
launchctl list | grep fr.even.agreg
# fr.even.agreg        → 22h55, génère la fiche + push
# fr.even.agreg.poller → chaque 60s, valide les rédactions
```

## Boucle quotidienne

1. **22h55 Mac** : fiche générée, push sur GitHub
2. **Ton réveil / soirée** : tu ouvres la page, bosses l'exo
3. **Avant de te coucher** : rédiges + soumets
4. **Dans la minute qui suit** : validation apparaît

## Commandes Mac

```bash
alias agreg='cd ~/agreg && ls -1t fiches/ | head -5'
alias agreg-generer='~/agreg/generer.sh'
alias agreg-valider='~/agreg/valider.sh'       # validation locale (sans passer par mobile)
alias agreg-log='tail -30 ~/agreg/logs/launch.log'
alias agreg-poller-log='tail -30 ~/agreg/logs/poller.log'
```

## Structure

```
~/agreg/
├── progression.json           # 150 sujets ordonnés (7 blocs)
├── etat.json                  # jour courant + historique
├── generer.sh                 # lancé par launchd à 22h55
├── poller.sh                  # lancé par launchd /60s
├── valider.sh                 # validation locale (secours)
├── prompts/
│   ├── generer.md
│   └── valider.md
├── docs/
│   └── index.html             # GitHub Pages
├── fiches/                    # 1 .md par jour (commité)
├── validations/               # 1 .md par rédaction (commité par poller)
└── logs/                      # local, gitignore
```

## Configuration (~/.config/agreg/)

- `github-token` : PAT GitHub (chmod 600)
- `env` : variables d'environnement (chmod 600)

## Désactiver temporairement

```bash
launchctl unload ~/Library/LaunchAgents/fr.even.agreg.plist
launchctl unload ~/Library/LaunchAgents/fr.even.agreg.poller.plist
```

## Phase 3 (à venir)

Blocage iOS via mode Concentration "Nuit Agrégation" désactivable seulement après validation réussie.
