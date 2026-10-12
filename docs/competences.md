# Catalogue des compétences — Lifantasy

> Document de conception : il recense les compétences qui doivent exister dans le jeu, avant leur saisie dans
> `claude_rpg/data/skills.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md).

## Règles générales

- Une compétence dépend d'**un attribut** (Athlétisme → Force…).
- **Test** : d20 + modificateur de l'attribut + bonus de maîtrise si la compétence est maîtrisée, contre un DD. Un 20
  naturel réussit toujours, un 1 naturel échoue toujours.
- **Maîtrise** : elle vient de la classe, du passé ou d'un don.
- **Expertise** : bonus de maîtrise doublé (Roublard, niveaux 1 et 6).
- **Talent fiable** : pour une compétence maîtrisée, un d20 sous 10 compte comme 10 (Roublard, niveau 11).
- Aujourd'hui, les compétences servent aux **tests des événements**. Le combat n'en utilise aucune.
- Les **jets de sauvegarde** sont à part : ils utilisent directement un attribut (voir [classes.md](classes.md)).

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Attribut** : FOR / DEX / CON / INT / SAG / CHA.
- **Sert à** : exemples de situations.
- **Maîtrisée par** : classes, passés, dons.
- **Usages prévus** : événements, combat, métiers, social…
- **Notes** : …
```

---

## Compétences implémentées (les 18 du SRD)

### Force

### Athlétisme (`athletics`)

- **Attribut** : FOR.
- **Sert à** : grimper, nager, sauter, forcer une porte, tenir une prise.
- **Maîtrisée par** : Guerrier ; passés Sauvageon, Soldat ; don Athlète.
- **Usages actuels** : aucun test d'événement pour l'instant.

### Dextérité

### Acrobaties (`acrobatics`)

- **Attribut** : DEX.
- **Sert à** : garder l'équilibre, esquiver, faire des cabrioles.
- **Maîtrisée par** : Roublard ; passé Saltimbanque ; don Agile.
- **Usages actuels** : aucun test d'événement pour l'instant.

### Escamotage (`sleight_of_hand`)

- **Attribut** : DEX.
- **Sert à** : voler à la tire, crocheter, glisser un objet discrètement.
- **Maîtrisée par** : Roublard ; passés Charlatan, Gamin des rues.
- **Usages actuels** : 1 test d'événement.

### Discrétion (`stealth`)

- **Attribut** : DEX.
- **Sert à** : se cacher, suivre quelqu'un, passer inaperçu.
- **Maîtrisée par** : Roublard ; passés Criminel, Gamin des rues.
- **Usages actuels** : 3 tests d'événements.

### Intelligence

### Arcanes (`arcana`)

- **Attribut** : INT.
- **Sert à** : reconnaître la magie, les sorts, les objets enchantés, les créatures surnaturelles.
- **Maîtrisée par** : Magicien ; passé Érudit.
- **Usages actuels** : 4 tests d'événements.

### Histoire (`history`)

- **Attribut** : INT.
- **Sert à** : se souvenir des événements passés, des lignées, des légendes.
- **Maîtrisée par** : passés Noble, Érudit.
- **Usages actuels** : aucun test d'événement pour l'instant.
- **Notes** : idéale pour la chronique des vies passées (reconnaître la tombe d'un ancien personnage…).

### Investigation (`investigation`)

- **Attribut** : INT.
- **Sert à** : chercher des indices, déduire, repérer un mécanisme.
- **Maîtrisée par** : Magicien ; don Artisan accompli.
- **Usages actuels** : aucun test d'événement pour l'instant.

### Nature (`nature`)

- **Attribut** : INT.
- **Sert à** : connaître plantes, animaux, terrain et météo.
- **Maîtrisée par** : don Érudit des arcanes.
- **Usages actuels** : aucun test d'événement pour l'instant.

### Religion (`religion`)

- **Attribut** : INT.
- **Sert à** : connaître les dieux, les rites, les morts-vivants et les êtres divins.
- **Maîtrisée par** : passé Acolyte ; don Doué.
- **Usages actuels** : 1 test d'événement.

### Sagesse

### Dressage (`animal_handling`)

- **Attribut** : SAG.
- **Sert à** : calmer, monter ou dresser un animal.
- **Maîtrisée par** : passé Héros du peuple.
- **Usages actuels** : aucun test d'événement pour l'instant.
- **Notes** : utile pour les voyages (montures) et les compagnons animaux.

### Médecine (`medicine`)

- **Attribut** : SAG.
- **Sert à** : soigner, diagnostiquer, stabiliser un mourant.
- **Maîtrisée par** : Magicien ; don Guérisseur.
- **Usages actuels** : 2 tests d'événements.

### Perception (`perception`)

- **Attribut** : SAG.
- **Sert à** : repérer, entendre, sentir le danger.
- **Maîtrisée par** : Guerrier, Roublard ; don Artisan accompli.
- **Usages actuels** : 1 test d'événement.

### Perspicacité (`insight`)

- **Attribut** : SAG.
- **Sert à** : deviner les intentions, déceler un mensonge.
- **Maîtrisée par** : passés Acolyte, Artisan ; dons Musicien, Doué.
- **Usages actuels** : aucun test d'événement pour l'instant.

### Survie (`survival`)

- **Attribut** : SAG.
- **Sert à** : pister, s'orienter, chasser, trouver un abri.
- **Maîtrisée par** : Guerrier ; passés Héros du peuple, Sauvageon.
- **Usages actuels** : 1 test d'événement.
- **Notes** : centrale pour les voyages (se perdre ou non).

### Charisme

### Intimidation (`intimidation`)

- **Attribut** : CHA.
- **Sert à** : menacer, impressionner, faire plier.
- **Maîtrisée par** : passé Soldat ; don Doué.
- **Usages actuels** : 2 tests d'événements.

### Persuasion (`persuasion`)

- **Attribut** : CHA.
- **Sert à** : convaincre, négocier, séduire.
- **Maîtrisée par** : passés Artisan, Noble ; don Langue d'argent.
- **Usages actuels** : 3 tests d'événements.
- **Notes** : servira aux prix des boutiques et aux relations sociales.

### Représentation (`performance`)

- **Attribut** : CHA.
- **Sert à** : chanter, jouer, conter, divertir une foule.
- **Maîtrisée par** : passé Saltimbanque.
- **Usages actuels** : aucun test d'événement pour l'instant.
- **Notes** : un métier possible (barde de taverne).

### Tromperie (`deception`)

- **Attribut** : CHA.
- **Sert à** : mentir, se déguiser, bluffer.
- **Maîtrisée par** : passés Charlatan, Criminel.
- **Usages actuels** : aucun test d'événement pour l'instant.

---

## Compétences candidates (à compléter)

Idées liées aux métiers et à la vie sédentaire. Dans D&D, ce sont des « maîtrises d'outils », mais on peut en faire
de vraies compétences.

### Artisanat / Forge

- **Attribut** : FOR ou INT ?
- **Sert à** : fabriquer et réparer armes, armures, objets.

### Alchimie

- **Attribut** : INT.
- **Sert à** : préparer potions, poisons, remèdes.

### Cuisine

- **Attribut** : SAG ?
- **Sert à** : préparer des repas (bonus temporaires, métier).

### Commerce

- **Attribut** : CHA ou INT ?
- **Sert à** : acheter et vendre au meilleur prix, tenir une boutique.

### Équitation / Conduite

- **Attribut** : DEX ou SAG ?
- **Sert à** : montures et attelages pendant les voyages.

---

## Questions ouvertes

1. **Métiers** : on ajoute de vraies compétences (Forge, Alchimie, Cuisine, Commerce…), ou des « maîtrises d'outils »
   à la D&D (maîtrisée ou non, sans attribut fixe) ?
2. **Compétences en combat** : Athlétisme pour agripper, Discrétion pour se cacher, Intimidation pour faire fuir,
   Médecine pour stabiliser un allié… Lesquelles ?
3. **Progression par l'usage** : les compétences restent-elles uniquement liées à la maîtrise (comme D&D), ou
   s'améliorent-elles aussi en les pratiquant (comme dans The Elder Scrolls), ce qui irait bien avec les métiers et le
   passage des années ?
4. **Choix des compétences** : aujourd'hui, la classe et le passé imposent les leurs. Dans D&D, on choisit 2 à 4
   compétences dans une liste de classe. On ajoute ce choix à l'écran de création ?
5. **Équilibre** : 9 compétences ne sont jamais testées par les événements actuels. Faut-il y veiller en écrivant
   le contenu ?
