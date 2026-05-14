#!/bin/bash
# ─────────────────────────────────────────────────────────
#  FranklinWH Auto-Save Setup — Mac
#  Double-click this file to install. Do this once.
# ─────────────────────────────────────────────────────────

clear
echo "╔════════════════════════════════════════╗"
echo "║    FranklinWH Auto-Save Setup          ║"
echo "╚════════════════════════════════════════╝"
echo ""

PROJECTS_DIR="${1:-$HOME/Desktop/Claude}"
AUTOSAVE_SCRIPT="$HOME/.claude-autosave.sh"
LOG_FILE="$HOME/claude-autosave.log"
ORG="FranklinWH-US"

# ── Step 1: Install gh CLI if missing ───────────────────
if ! command -v gh &>/dev/null; then
  echo "Installing GitHub CLI..."
  if command -v brew &>/dev/null; then
    brew install gh 2>&1 | tail -2
  else
    echo ""
    echo "  Please install the GitHub CLI first:"
    echo "  → https://github.com/cli/gh/releases/latest"
    echo "  Download the macOS .pkg file, install it,"
    echo "  then double-click this setup file again."
    echo ""
    read -rp "Press Enter to close..."
    exit 1
  fi
fi

# ── Step 2: GitHub login ─────────────────────────────────
echo ""
if ! gh auth status &>/dev/null 2>&1; then
  echo "Opening GitHub login in your browser..."
  echo "(Sign in with the GitHub account you just created)"
  echo ""
  gh auth login --web -h github.com
else
  GH_USER=$(gh api user --jq '.login' 2>/dev/null)
  echo "✓ Already logged in as: $GH_USER"
fi
echo ""

# ── Step 3: Write the autosave script ───────────────────
cat > "$AUTOSAVE_SCRIPT" << 'SCRIPT'
#!/bin/bash
LOG="__LOG_FILE__"
PROJECTS="__PROJECTS_DIR__"
ORG="FranklinWH-US"

echo "=== Auto-save $(date '+%Y-%m-%d %H:%M') ===" >> "$LOG"

find "$PROJECTS" -maxdepth 2 -name ".git" -type d 2>/dev/null | while IFS= read -r g; do
  repo="$(dirname "$g")"
  cd "$repo" || continue
  name=$(basename "$repo")

  # If no remote yet, create repo under the org and push
  if ! git remote get-url origin &>/dev/null 2>&1; then
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
      if git rev-parse HEAD &>/dev/null 2>&1; then
        echo "  Creating FranklinWH-US/$name" >> "$LOG"
        gh repo create "$ORG/$name" --private --source="$repo" --push --remote origin >> "$LOG" 2>&1 \
          || echo "  (could not create $ORG/$name — may already exist)" >> "$LOG"
      fi
    else
      echo "  (no remote — run setup again to connect to GitHub)" >> "$LOG"
    fi
    continue
  fi

  # Nothing to commit — skip silently
  [ -z "$(git status --porcelain 2>/dev/null)" ] && continue

  echo "  Saving: $name" >> "$LOG"
  git add -A >> "$LOG" 2>&1
  git commit -m "Auto-save $(date '+%Y-%m-%d %H:%M')" >> "$LOG" 2>&1
  git push origin main >> "$LOG" 2>&1
done
SCRIPT

sed -i '' "s|__LOG_FILE__|$LOG_FILE|g"        "$AUTOSAVE_SCRIPT"
sed -i '' "s|__PROJECTS_DIR__|$PROJECTS_DIR|g" "$AUTOSAVE_SCRIPT"
chmod +x "$AUTOSAVE_SCRIPT"

# ── Step 4: Register cron (9am · 1pm · 5pm Mon–Fri) ────
( crontab -l 2>/dev/null | grep -v "claude-autosave"; \
  echo "0 9,13,17 * * 1-5 /bin/bash $AUTOSAVE_SCRIPT" ) | crontab -

# ── Step 5: Run once now ─────────────────────────────────
echo "Running first save..."
bash "$AUTOSAVE_SCRIPT"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✓  You're all set!                    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "  Watching : $PROJECTS_DIR"
echo "  Saves to : github.com/$ORG"
echo "  Schedule : 9am · 1pm · 5pm, Mon–Fri"
echo "  Log      : $LOG_FILE"
echo ""
echo "  Your work backs up to the FranklinWH GitHub"
echo "  automatically. Nothing else to do."
echo ""
read -rp "Press Enter to close..."
