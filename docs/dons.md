# Catalogue des dons — Lifantasy

> Document de conception : il recense les dons qui doivent exister dans le jeu, avant leur saisie dans
> `claude_rpg/data/feats.json`. Les champs techniques (prérequis, modificateurs) sont détaillés dans
> [modele_donnees.md](modele_donnees.md), rubriques Dons et Modificateurs.

## Règles générales

- **Comment on obtient un don** :
  - **Passé** : chaque passé en accorde un dès la création (un don « d'origine »).
  - **Espèce** : l'humain choisit un don supplémentaire au début de la partie.
  - **Niveau** : aux niveaux 4, 8, 12, 16 et 20, +1 à un attribut **et** un don au choix.
  - **Événement** : un événement peut en donner un.
- Deux catégories :
  - **Origine** : dons de départ, liés aux passés ;
  - **Général** : dons qu'on choisit en montant de niveau, parfois avec des prérequis.
- Un don ne se prend qu'une fois.
- Ce qu'un don peut faire aujourd'hui :
  - bonus d'attribut, de CA, d'initiative, de PV par niveau, aux dégâts ou au toucher avec une arme, aux sauvegardes ;
  - maîtrise ou expertise d'une compétence, maîtrise d'une sauvegarde ;
  - résistance, immunité ou vulnérabilité à un type de dégâts, immunité à un état.

  Il ne peut **pas encore** donner une action de combat ni un sort : il faudra l'ajouter pour certains dons
  candidats.
- ⚠️ Licence : le SRD 5.2 (2025, CC-BY 4.0) contient une partie des dons de D&D 2024 (Vigilant, Doué, Frappe
  brutale, Initié à la magie, Lutteur…). Les autres sont à concevoir nous-mêmes.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Catégorie** : origine / général.
- **Prérequis** : aucun / attribut minimum / classe / niveau…
- **Effet** : ce que le don fait, en une ou deux phrases.
- **Obtenu par** : passé X, montée de niveau, événement…
- **Notes** : …
```

---

## Dons d'origine (implémentés)

### Vigilant (`alert`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +5 à l'initiative.
- **Obtenu par** : passé Criminel.

### Robuste (`tough`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +2 PV max par niveau.
- **Obtenu par** : passé Héros du peuple.

### Guérisseur (`healer`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +1 SAG, maîtrise de Médecine.
- **Obtenu par** : passé Acolyte.

### Artisan accompli (`crafter`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : maîtrise d'Investigation et de Perception.
- **Obtenu par** : passé Artisan.
- **Notes** : à revoir quand l'artisanat existera (réduction des prix, fabrication plus rapide…).

### Langue d'argent (`silver_tongue`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +1 CHA, maîtrise de Persuasion.
- **Obtenu par** : passé Charlatan.

### Musicien (`musician`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +1 CHA, maîtrise de Perspicacité.
- **Obtenu par** : passé Saltimbanque.
- **Notes** : dans D&D 2024, il inspire les alliés après un repos (PV temporaires). À envisager.

### Doué (`skilled`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : maîtrise de Perspicacité, d'Intimidation et de Religion.
- **Obtenu par** : passé Noble.
- **Notes** : dans D&D, on choisit les trois compétences. Il faudrait un écran de choix.

### Athlète (`athlete`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +1 FOR, maîtrise d'Athlétisme.
- **Obtenu par** : passé Sauvageon.

### Érudit des arcanes (`scholar`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +1 INT, maîtrise de Nature.
- **Obtenu par** : passé Érudit.

### Frappe brutale (`savage_attacker`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +1 aux dégâts des attaques d'arme.
- **Obtenu par** : passé Soldat.
- **Notes** : dans D&D 2024, on relance les dés de dégâts une fois par tour et on garde le meilleur.

### Agile (`nimble`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : +1 DEX, maîtrise d'Acrobaties.
- **Obtenu par** : passé Gamin des rues.

---

## Dons généraux (implémentés)

### Duelliste défensif (`defensive_duelist`)

- **Catégorie** : général.
- **Prérequis** : DEX 13.
- **Effet** : +1 CA.
- **Notes** : dans D&D, c'est une réaction (parade). À revoir quand les réactions seront plus complètes.

### Résistant (`resilient`)

- **Catégorie** : général.
- **Prérequis** : CON 13.
- **Effet** : +1 CON, résistance au poison, immunité à l'état Poison.
- **Notes** : dans D&D, Résistant donne la maîtrise d'une sauvegarde au choix. On pourrait l'aligner.

### Adepte élémentaire (`elemental_adept`)

- **Catégorie** : général.
- **Prérequis** : classe Magicien.
- **Effet** : +1 INT, résistance au feu.
- **Notes** : dans D&D, il fait ignorer la résistance de la cible à un élément. À envisager avec le choix de
  l'élément.

### Entraînement aux armures lourdes (`heavy_armor_training`)

- **Catégorie** : général.
- **Prérequis** : niveau 4.
- **Effet** : +1 FOR, +1 CA.
- **Notes** : avec l'encombrement, il pourrait plutôt **supprimer les malus** d'une armure trop lourde.

---

## Dons candidats (à compléter)

### Amélioration d'attribut

- **Catégorie** : général.
- **Effet envisagé** : +2 à un attribut, ou +1 à deux attributs (le don « par défaut » de D&D).

### Chanceux

- **Catégorie** : origine ou général.
- **Effet envisagé** : quelques relances de d20 par repos long.

### Initié à la magie (SRD 5.2)

- **Catégorie** : origine.
- **Effet envisagé** : deux tours de magie et un sort du 1er niveau d'une autre classe.
- **Notes** : demande qu'un don puisse donner des actions de combat.

### Lutteur (SRD)

- **Catégorie** : général.
- **Effet envisagé** : agripper un ennemi (état Agrippé, voir [etats.md](etats.md)).

### Bagarreur de taverne

- **Catégorie** : origine.
- **Effet envisagé** : mains nues à 1d4, bonus dans les bagarres de taverne (combats en K.-O.).

### Sentinelle

- **Catégorie** : général.
- **Effet envisagé** : attaque de réaction quand un ennemi frappe un allié.

### Maître des armes lourdes

- **Catégorie** : général.
- **Effet envisagé** : avec une arme lourde, −5 au toucher pour +10 aux dégâts (option à activer).

### Dons de métier (idées propres au jeu)

- **Effet envisagé** : un don par métier (Forgeron né, Cuisinier hors pair, Négociant…), qui améliore les
  mini-jeux de métier.

---

## Décisions (2026-10-13)

- **Versions des dons** : se rapprocher des règles libres de droit (SRD 5.2) dans leur version complète, pas
  simplifiée. À faire : revoir Frappe brutale, Résistant, Adepte élémentaire, Musicien…
- **Dons à choix** (Doué, Résistant, Adepte élémentaire…) : oui, avec un écran de choix.
- **Dons qui donnent des actions ou des sorts** : possible.
- **Tous les 4 niveaux** : un attribut **et** un don. On n'a jamais à choisir entre améliorer ses statistiques et
  développer son personnage avec un don intéressant.

## Questions ouvertes

1. **Dons de métier** : pas certain, à voir avec les métiers.
