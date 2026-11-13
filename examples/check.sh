#!/usr/bin/env bash
# check.sh "prompt text" — ask the Habits guard whether user-typed text is a prompt injection.
# With HABITS_KEY set it asks your own trainable guard; without it, the public guard (30 checks/day per network).
# Exit code: 0 = clean, 1 = flagged, 2 = error.  Requires curl and jq.
set -euo pipefail
B=${HABITS_URL:-https://habits.darmousseh.com}
text=${1:?usage: check.sh "prompt text"}
if [ -n "${HABITS_KEY:-}" ]; then
  user=$(curl -fsS "$B/v1/me" -H "authorization: Bearer $HABITS_KEY" | jq -r .username)
  r=$(curl -fsS -X POST "$B/v1/systemone" -H "authorization: Bearer $HABITS_KEY" -H 'content-type: application/json' \
      -d "$(jq -nc --arg t "$text" --arg h "$user.guard.prompt-injection" '{store:true,questions:{guard:{type:"noul",habit:$h}},state:$t}')") || exit 2
  score=$(jq -r .answers.guard.noul <<<"$r"); echo "score=$score request_id=$(jq -r .request_id <<<"$r")"
else
  r=$(curl -fsS -X POST "$B/v1/try" -H 'content-type: application/json' -d "$(jq -nc --arg t "$text" '{text:$t}')") || exit 2
  score=$(jq -r .habit.score <<<"$r"); echo "score=$score (public guard)"
fi
awk -v s="$score" 'BEGIN{exit !(s >= 0.5)}' && { echo flagged; exit 1; } || { echo clean; exit 0; }
