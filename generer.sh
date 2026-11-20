#!/usr/bin/env bash
# Génère la fiche agreg du jour via Claude CLI.
# Appelé par launchd chaque soir à 22h55.

set -euo pipefail

AGREG_DIR="$HOME/agreg"
LOG="$AGREG_DIR/logs/launch.log"
DATE=$(date +%Y-%m-%d)
HEURE=$(date +%H:%M:%S)

mkdir -p "$AGREG_DIR/logs" "$AGREG_DIR/fiches"

echo "[$DATE $HEURE] --- Démarrage génération ---" >> "$LOG"

# Si une fiche existe déjà pour aujourd'hui, ne rien faire
if [ -f "$AGREG_DIR/fiches/$DATE.md" ]; then
  echo "[$DATE $HEURE] Fiche déjà présente — skip" >> "$LOG"
  exit 0
fi

# Charger PATH complet (launchd démarre avec un PATH minimal)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"

CLAUDE_BIN="$(command -v claude || echo /Users/florian/.local/bin/claude)"
if [ ! -x "$CLAUDE_BIN" ]; then
  echo "[$DATE $HEURE] ERREUR: claude CLI introuvable" >> "$LOG"
  exit 1
fi

cd "$AGREG_DIR"

# Charge GH_TOKEN pour permettre git push vers le repo privé (via gh credential helper)
# shellcheck disable=SC1090
[ -f "$HOME/.config/agreg/env" ] && source "$HOME/.config/agreg/env"

# Lancer Claude en mode non-interactif via stdin
if cat "$AGREG_DIR/prompts/generer.md" | "$CLAUDE_BIN" \
     --print \
     --permission-mode acceptEdits \
     --allowedTools "Read,Write,Edit,Bash" \
     --add-dir "$AGREG_DIR" \
     >> "$LOG" 2>&1 ; then
  echo "[$DATE $(date +%H:%M:%S)] Génération OK" >> "$LOG"
else
  echo "[$DATE $(date +%H:%M:%S)] ERREUR génération (code $?)" >> "$LOG"
fi

# Pousse la fiche vers GitHub pour que la page la voie
if [ -f "$AGREG_DIR/fiches/$DATE.md" ]; then
  if git -C "$AGREG_DIR" add fiches/ etat.json validations/ 2>/dev/null && \
     git -C "$AGREG_DIR" diff --cached --quiet; then
    echo "[$DATE $(date +%H:%M:%S)] Rien à pousser" >> "$LOG"
  else
    git -C "$AGREG_DIR" commit -m "fiche $DATE" >> "$LOG" 2>&1 || true
    git -C "$AGREG_DIR" push >> "$LOG" 2>&1 \
      && echo "[$DATE $(date +%H:%M:%S)] Push OK" >> "$LOG" \
      || echo "[$DATE $(date +%H:%M:%S)] Push échoué" >> "$LOG"
  fi
fi

echo "[$DATE $(date +%H:%M:%S)] --- Fin ---" >> "$LOG"
