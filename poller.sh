#!/usr/bin/env bash
# Poller : scrute les issues GitHub avec label "agreg-redaction",
# appelle Claude CLI pour valider, poste le commentaire, ferme l'issue.
# Lancé par launchd chaque minute (~fr.even.agreg.poller).

set -euo pipefail

AGREG_DIR="$HOME/agreg"
LOG="$AGREG_DIR/logs/poller.log"
LOCK="$AGREG_DIR/logs/poller.lock"
REPO="feven-NIT/agreg"

mkdir -p "$AGREG_DIR/logs"

# Évite les exécutions concurrentes
if [ -f "$LOCK" ]; then
  if ps -p "$(cat "$LOCK")" > /dev/null 2>&1; then
    exit 0
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

ts() { date +'%Y-%m-%d %H:%M:%S'; }

# Charge token GitHub + PATH complet
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
# shellcheck disable=SC1090
source "$HOME/.config/agreg/env"

GH_BIN="$(command -v gh)"
CLAUDE_BIN="$(command -v claude || echo /Users/florian/.local/bin/claude)"

if [ -z "$GH_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
  echo "[$(ts)] ERREUR: gh ou claude introuvable" >> "$LOG"
  exit 1
fi

# Liste les issues ouvertes avec le label
ISSUES_JSON=$("$GH_BIN" issue list --repo "$REPO" --label agreg-redaction --state open --json number,title,body,createdAt --limit 10)

COUNT=$(echo "$ISSUES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
if [ "$COUNT" = "0" ]; then
  exit 0
fi

echo "[$(ts)] $COUNT issue(s) à traiter" >> "$LOG"

PROMPT_VALIDER=$(cat "$AGREG_DIR/prompts/valider.md")

echo "$ISSUES_JSON" | python3 -c "
import sys, json
for issue in json.load(sys.stdin):
    print(f\"{issue['number']}|||{issue['body']}\")
" | while IFS='|||' read -r NUM BODY; do
  # NUM reçoit le numéro, BODY reçoit le body (peut avoir des sauts de ligne encodés)
  if [ -z "$NUM" ]; then continue; fi
  echo "[$(ts)] Traitement issue #$NUM" >> "$LOG"

  # Récupère la date de la fiche depuis le body
  DATE=$(echo "$BODY" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)
  if [ -z "$DATE" ] || [ ! -f "$AGREG_DIR/fiches/$DATE.md" ]; then
    DATE=$(ls -1t "$AGREG_DIR/fiches/"*.md 2>/dev/null | head -1 | xargs -I{} basename {} .md)
  fi
  FICHE_PATH="$AGREG_DIR/fiches/$DATE.md"

  if [ ! -f "$FICHE_PATH" ]; then
    "$GH_BIN" issue comment "$NUM" --repo "$REPO" --body "Aucune fiche trouvée pour valider. Abandon." > /dev/null
    "$GH_BIN" issue close "$NUM" --repo "$REPO" > /dev/null
    continue
  fi

  # Récupère la rédaction (texte après "---")
  REDACTION=$(echo "$BODY" | python3 -c "
import sys
txt = sys.stdin.read()
if '---' in txt:
    print(txt.split('---', 1)[1].strip())
else:
    print(txt.strip())
")

  # Construit l'input pour Claude
  INPUT=$(cat <<EOF
$PROMPT_VALIDER

---

## Fiche à relire
$(cat "$FICHE_PATH")

---

## Rédaction de Florian (issue #$NUM)

$REDACTION

---

Produis UNIQUEMENT la validation au format Markdown demandé, commençant par \`# Validation —\`.
Ne lis aucun fichier supplémentaire ni ne fais d'appel d'outil. Réponds directement avec la validation.
EOF
)

  VALIDATION=$(echo "$INPUT" | "$CLAUDE_BIN" --print --permission-mode acceptEdits --allowedTools "Read" --add-dir "$AGREG_DIR" 2>>"$LOG")

  if [ -z "$VALIDATION" ]; then
    echo "[$(ts)] ERREUR: validation vide pour #$NUM" >> "$LOG"
    continue
  fi

  # Marqueur magique pour que la page le reconnaisse
  COMMENT=$(printf "<!-- agreg-validation -->\n%s" "$VALIDATION")

  # Poste + ferme + sauvegarde
  echo "$COMMENT" | "$GH_BIN" issue comment "$NUM" --repo "$REPO" --body-file - > /dev/null
  "$GH_BIN" issue close "$NUM" --repo "$REPO" > /dev/null

  TS_FILE=$(date +%Y-%m-%d_%H%M%S)
  mkdir -p "$AGREG_DIR/validations"
  echo "$COMMENT" > "$AGREG_DIR/validations/${TS_FILE}-issue${NUM}.md"

  echo "[$(ts)] Issue #$NUM validée" >> "$LOG"
done
