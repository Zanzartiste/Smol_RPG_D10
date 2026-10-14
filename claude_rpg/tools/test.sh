#!/usr/bin/env bash
# Tests headless, sortie réduite aux échecs, erreurs de script et au bilan.
#   tools/test.sh               tous les tests
#   tools/test.sh quick         sans la simulation (rapide)
#   tools/test.sh social,quests seulement les tests dont le nom contient ces mots
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-/c/Program Files (x86)/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe}"
timeout 280 "$GODOT" --headless --path . res://tests/test_runner.tscn -- "$@" 2>&1 \
	| grep -E "ÉCHEC|SCRIPT ERROR|Parse Error|^   at: .*res://|^  [^ ]|vérifications" | head -40
