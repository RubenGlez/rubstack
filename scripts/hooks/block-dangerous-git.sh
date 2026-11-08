#!/usr/bin/env bash
# Block dangerous git operations that cannot be undone.
# PreToolUse — Bash. Exits 2 to block; 0 to allow.

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool" != "Bash" ] && exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
echo "$cmd" | grep -q '\bgit\b' || exit 0

blocked=""

# Push checks read one shell segment at a time, so a flag from another command
# in the chain (`rm -f x && git push`) is not taken for a push flag.
nl=$'\n'
segments=${cmd//&&/$nl}
segments=${segments//||/$nl}
segments=${segments//;/$nl}
segments=${segments//|/$nl}
while IFS= read -r seg; do
  echo "$seg" | grep -qE '\bgit\b.*\bpush\b' || continue
  # git push --force / -f (any position within the push)
  echo "$seg" | grep -qE '(^|\s)(--force|-f)(\s|$)' && blocked="git push --force"
  # git push with +refspec (force push in disguise)
  echo "$seg" | grep -qE '\s\+[a-zA-Z]' && blocked="git push +refspec"
done <<< "$segments"

# git reset --hard
echo "$cmd" | grep -qE '\bgit\s+reset\s+--hard' && blocked="git reset --hard"

# git clean -f (any combo of -f -d -x)
echo "$cmd" | grep -qE '\bgit\s+clean\s+-[fdx]*f[fdx]*(\s|$)' && blocked="git clean -f"

# git branch -D
echo "$cmd" | grep -qE '\bgit\s+branch\s+-D\b' && blocked="git branch -D"

# git checkout . or git checkout -- . (bare dot only — pathspecs like .rubstack are legitimate restores)
echo "$cmd" | grep -qE '\bgit\s+checkout\s+(\.|--\s+\.)(\s|$)' && blocked="git checkout ."

# git restore . (discards all working tree changes; bare dot only)
echo "$cmd" | grep -qE '\bgit\s+restore\s+\.(\s|$)' && blocked="git restore ."

# git stash drop / clear (discards stashed work)
echo "$cmd" | grep -qE '\bgit\s+stash\s+(drop|clear)\b' && blocked="git stash drop/clear"

# git reflog expire (destroys recovery history)
echo "$cmd" | grep -qE '\bgit\s+reflog\s+expire\b' && blocked="git reflog expire"

if [ -n "$blocked" ]; then
  echo "Blocked: $blocked — this operation cannot be undone." >&2
  echo "If you're sure, run the command directly in your terminal." >&2
  exit 2
fi

exit 0
