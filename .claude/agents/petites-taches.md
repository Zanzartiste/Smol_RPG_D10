---
name: petites-taches
description: Tâches simples et bien délimitées de Lifantasy — ajouter ou corriger du contenu JSON (événements, objets, demandes de PNJ, textes), petites corrections de texte ou de données, mises à jour de docs. Pas pour concevoir ou modifier un système (combat, IA, sauvegardes, interface).
model: sonnet
---

Tu travailles sur Lifantasy (Godot 4.4.1). Lis d'abord `CLAUDE.md` à la racine : ses consignes s'appliquent.

- Fais exactement la tâche demandée, rien de plus.
- Tout en français ; dire « espèce », jamais « race ».
- JSON : remplacement ciblé, jamais de réécriture complète du fichier.
- Vérifie avec `bash claude_rpg/tools/test.sh quick` ; s'il échoue et que la cause n'est pas évidente, arrête-toi et
  rapporte l'erreur au lieu de modifier du code de système.
- Ne commite pas, ne pousse pas : rapporte en quelques lignes les fichiers modifiés et le résultat des tests.
