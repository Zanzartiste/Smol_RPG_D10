# Lifantasy — consignes pour Claude

RPG narratif roguelite, Godot 4.4.1, GDScript typé. Jeu dans `claude_rpg/`, conception dans `docs/`.
Réponses, docs, textes du jeu et commits **en français**. Dire « espèce », jamais « race ».

## Économie de contexte (prioritaire)
- Ne pas relire un gros fichier en entier : `grep -n` puis lire la plage utile (`sed -n a,bp`).
  Gros fichiers : `tests/test_runner.gd` (2300 l.), `combat/combat.gd`, `model/character.gd`, `social/social.gd`.
- Tests : `bash tools/test.sh quick` (6 s) pendant le travail ; `bash tools/test.sh <mot>` pour un domaine ;
  la suite complète (`bash tools/test.sh`, ~2 min, simulation comprise) une fois, avant le commit.
- Pas de captures d'écran ni de banc d'équilibrage (`tools/combat_bench.tscn`, très long) sans demande ou
  besoin réel (nouvel écran, changement d'équilibrage).
- Réponses courtes ; pas de récapitulatif de ce qui vient d'être montré.

## Répartition des modèles (demandée par l'utilisateur)
- Tâche simple et délimitée (contenu JSON, textes, petite correction, mise à jour de doc) : la déléguer à
  l'agent `petites-taches` (Sonnet) avec une consigne précise (fichiers, ids, valeurs attendues), puis relire
  son rapport et commiter. Pas d'autre sous-agent.
- Conception ou modification d'un système (combat, IA, règles, sauvegardes, interface) : la faire soi-même.
- Une fonctionnalité finie et commitée : proposer à l'utilisateur de taper `/clear` (un hook le rappelle aussi).

## Commandes (depuis `claude_rpg/`)
- Godot : `/c/Program Files (x86)/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64_console.exe`
- Après l'ajout d'un fichier avec `class_name` : `<godot> --headless --path . --import`.
- Vérifier un script : `<godot> --headless --path . --check-only --script res://scripts/....gd`.
- Captures : `<godot> --path . res://tools/screenshot.tscn -- <dossier>` (a besoin d'une fenêtre).

## Conventions
- Données dans `claude_rpg/data/*.json`, validées par `scripts/core/data_validator.gd` (y ajouter tout nouveau champ).
  Éditer le JSON par remplacement ciblé : ne jamais le réécrire avec `json.dump` (reformate tout le fichier).
- Chaque fonctionnalité : code + données + test dans `tests/test_runner.gd` (ajouter la fonction à `TESTS`)
  + mise à jour de `docs/modele_donnees.md` / `docs/systeme_de_jeu.md`.
- Fonctions de combat = coroutines (`await`). Les tests ne touchent jamais aux vraies sauvegardes (`Saves.enabled = false`).
- Docs que l'utilisateur remplit : titres et listes, pas de tableaux Markdown.

## Git
- Travailler sur `dev` ; merger dans `main` (déployé sur GitHub Pages) seulement après accord explicite.
- Ne pas commiter `claude_rpg/scenes/title.tscn` si seul l'éditeur l'a modifié.
- Messages de commit en français, terminés par la ligne Co-Authored-By.
- Ne jamais tuer le processus de l'éditeur Godot de l'utilisateur.
