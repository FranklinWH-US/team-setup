#!/bin/bash
# ============================================================
# FranklinWH — Git Auto-Save Setup
# Run this ONCE in your terminal to protect your work.
#
# Usage:
#   bash ~/Desktop/Claude/setup-autosave.sh
#
# Custom project path (optional):
#   bash ~/Desktop/Claude/setup-autosave.sh ~/my-other-folder
# ============================================================

PROJECTS_DIR="${1:-$HOME/Desktop/Claude}"
AUTOSAVE_SCRIPT="$HOME/.claude-autosave.sh"
LOG_FILE="$HOME/claude-autosave.log"

# ── 1. Write the autosave script (single-quoted heredoc = no expansion) ─
cat > "$AUTOSAVE_SCRIPT" << 'SCRIPT'
#!/bin/bash
LOG="__LOG_FILE__"
PROJECTS="__PROJECTS_DIR__"
echo "=== Auto-save $(date '+%Y-%m-%d %H:%M') ===" >> "$LOG"
find "$PROJECTS" -maxdepth 2 -name ".git" -type d 2>/dev/null | while IFS= read -r g; do
  repo="$(dirname "$g")"
  cd "$repo" || continue
  [ -z "$(git status --porcelain 2>/dev/null)" ] && continue
  name=$(basename "$repo")
  echo "  Saving: $name" >> "$LOG"
  git add -A >> "$LOG" 2>&1
  git commit -m "Auto-save $(date '+%Y-%m-%d %H:%M')" >> "$LOG" 2>&1
  git remote get-url origin &>/dev/null \
    && git push origin main >> "$LOG" 2>&1 \
    || echo "  (no remote — committed locally only)" >> "$LOG"
done
SCRIPT

# Substitute placeholders with real paths
sed -i '' "s|__LOG_FILE__|$LOG_FILE|g"       "$AUTOSAVE_SCRIPT"
sed -i '' "s|__PROJECTS_DIR__|$PROJECTS_DIR|g" "$AUTOSAVE_SCRIPT"
chmod +x "$AUTOSAVE_SCRIPT"

# ── 2. Register cron (9am · 1pm · 5pm, Mon–Fri) — idempotent ────────────
( crontab -l 2>/dev/null | grep -v "claude-autosave"; \
  echo "0 9,13,17 * * 1-5 /bin/bash $AUTOSAVE_SCRIPT" ) | crontab -

# ── 3. Run once now so you can see it working immediately ────────────────
bash "$AUTOSAVE_SCRIPT"

echo ""
echo "✓ Auto-save is set up!"
echo "  Watching : $PROJECTS_DIR"
echo "  Schedule : 9am · 1pm · 5pm, Mon–Fri"
echo "  Log      : $LOG_FILE"
echo ""
echo "  To check it any time: cat ~/claude-autosave.log"
