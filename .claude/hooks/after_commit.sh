#!/usr/bin/env bash
# Hook PostToolUse (Bash) : après un « git commit » réussi, rappelle de vider le contexte.
input=$(cat)
if printf '%s' "$input" | grep -q '"command":"[^"]*git commit'; then
	printf '%s\n' '{"systemMessage": "Commit fait : si la fonctionnalité est finie, tape /clear pour repartir d'"'"'un contexte vide (CLAUDE.md et la mémoire sont rechargés)."}'
fi
exit 0
