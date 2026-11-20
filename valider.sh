#!/usr/bin/env bash
# Workflow de validation texte : lit la rédaction depuis stdin ou un fichier texte,
# lance Claude pour valider. Aucune photo.
#
# Usage :
#   agreg-valider                # session interactive (colle ta rédaction)
#   agreg-valider redac.txt      # depuis un fichier texte
#   echo "..." | agreg-valider - # depuis stdin

set -euo pipefail

AGREG_DIR="$HOME/agreg"
CLAUDE_BIN="$(command -v claude || echo /Users/florian/.local/bin/claude)"
cd "$AGREG_DIR"

DATE=$(date +%Y-%m-%d)
FICHE="$AGREG_DIR/fiches/$DATE.md"

if [ ! -f "$FICHE" ]; then
  FICHE=$(ls -1t "$AGREG_DIR/fiches/"*.md 2>/dev/null | head -1 || true)
  if [ -z "$FICHE" ]; then
    echo "Aucune fiche trouvée dans $AGREG_DIR/fiches/." >&2
    exit 1
  fi
  echo "ℹ️  Pas de fiche pour aujourd'hui, j'utilise : $(basename "$FICHE")"
fi

PROMPT_VALIDER=$(cat "$AGREG_DIR/prompts/valider.md")

# Cas 1 : argument = fichier texte
if [ $# -ge 1 ] && [ "$1" != "-" ] && [ -f "$1" ]; then
  REDACTION=$(cat "$1")
# Cas 2 : stdin explicite
elif [ "${1:-}" = "-" ]; then
  REDACTION=$(cat)
# Cas 3 : interactif — demande la rédaction
else
  echo "📄 Fiche : $(basename "$FICHE")"
  echo "✍️  Colle ta rédaction (termine avec Ctrl-D sur une ligne vide) :"
  echo "-----"
  REDACTION=$(cat)
  echo "-----"
fi

if [ -z "${REDACTION//[[:space:]]/}" ]; then
  echo "Rédaction vide. Rien à valider." >&2
  exit 1
fi

# Lancer Claude en non-interactif via stdin
INPUT=$(cat <<EOF
$PROMPT_VALIDER

---

## Fiche du jour à relire
Chemin : $FICHE

## Rédaction de Florian

$REDACTION
EOF
)

echo "$INPUT" | "$CLAUDE_BIN" \
  --print \
  --permission-mode acceptEdits \
  --allowedTools "Read,Write,Edit,Bash" \
  --add-dir "$AGREG_DIR"
