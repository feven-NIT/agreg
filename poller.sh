#!/usr/bin/env bash
# Poller : scrute les issues GitHub avec label "agreg-redaction",
# appelle Claude CLI pour valider, poste le commentaire, ferme l'issue.
# Lancé par launchd chaque minute (fr.even.agreg.poller).

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
ISSUES_JSON=$("$GH_BIN" issue list --repo "$REPO" --label agreg-redaction --state open --json number --limit 10)
NUMBERS=$(echo "$ISSUES_JSON" | python3 -c "import sys,json; [print(i['number']) for i in json.load(sys.stdin)]")

if [ -z "$NUMBERS" ]; then
  exit 0
fi

echo "[$(ts)] Issues à traiter : $(echo "$NUMBERS" | tr '\n' ' ')" >> "$LOG"

PROMPT_VALIDER=$(cat "$AGREG_DIR/prompts/poller-valider.md")

for NUM in $NUMBERS; do
  echo "[$(ts)] Traitement issue #$NUM" >> "$LOG"

  # Récupère le body
  BODY=$("$GH_BIN" issue view "$NUM" --repo "$REPO" --json body --jq .body)

  # Récupère la date de la fiche depuis le body
  DATE=$(echo "$BODY" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)
  if [ -z "$DATE" ] || [ ! -f "$AGREG_DIR/fiches/$DATE.md" ]; then
    DATE=$(ls -1t "$AGREG_DIR/fiches/"*.md 2>/dev/null | head -1 | xargs -I{} basename {} .md)
  fi
  FICHE_PATH="$AGREG_DIR/fiches/$DATE.md"

  if [ ! -f "$FICHE_PATH" ]; then
    echo "Aucune fiche trouvée pour valider. Abandon." | "$GH_BIN" issue comment "$NUM" --repo "$REPO" --body-file - > /dev/null
    "$GH_BIN" issue close "$NUM" --repo "$REPO" > /dev/null
    continue
  fi

  # Récupère la rédaction (texte après le premier "---")
  REDACTION_FILE=$(mktemp)
  printf '%s' "$BODY" > "$REDACTION_FILE.body"
  python3 - <<PY > "$REDACTION_FILE"
with open("$REDACTION_FILE.body") as f:
    txt = f.read()
print(txt.split("---", 1)[1].strip() if "---" in txt else txt.strip())
PY
  REDACTION=$(cat "$REDACTION_FILE")
  rm -f "$REDACTION_FILE" "$REDACTION_FILE.body"

  # Construit l'input Claude dans un fichier temp
  INPUT_FILE=$(mktemp)
  {
    cat "$AGREG_DIR/prompts/poller-valider.md"
    echo
    echo "===== DEBUT DE LA FICHE DU JOUR ====="
    echo
    cat "$FICHE_PATH"
    echo
    echo "===== FIN DE LA FICHE ====="
    echo
    echo "===== DEBUT DE LA REDACTION DE FLORIAN issue $NUM ====="
    echo
    printf '%s\n' "$REDACTION"
    echo
    echo "===== FIN DE LA REDACTION ====="
    echo
    echo "Produis UNIQUEMENT la validation au format Markdown demande, commencant par # Validation."
  } > "$INPUT_FILE"

  VALIDATION=$("$CLAUDE_BIN" --print --permission-mode default --disallowedTools "Read,Write,Edit,Bash,Glob,Grep,WebFetch,WebSearch" < "$INPUT_FILE" 2>>"$LOG")
  rm -f "$INPUT_FILE"

  if [ -z "$VALIDATION" ]; then
    echo "[$(ts)] ERREUR: validation vide pour #$NUM" >> "$LOG"
    continue
  fi

  COMMENT=$(printf "<!-- agreg-validation -->\n%s" "$VALIDATION")

  echo "$COMMENT" | "$GH_BIN" issue comment "$NUM" --repo "$REPO" --body-file - > /dev/null
  "$GH_BIN" issue close "$NUM" --repo "$REPO" > /dev/null

  TS_FILE=$(date +%Y-%m-%d_%H%M%S)
  mkdir -p "$AGREG_DIR/validations"
  echo "$COMMENT" > "$AGREG_DIR/validations/${TS_FILE}-issue${NUM}.md"

  echo "[$(ts)] Issue #$NUM validée" >> "$LOG"
done
