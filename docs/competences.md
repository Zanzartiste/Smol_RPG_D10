# Catalogue des compétences — Lifantasy

> Document de conception : il recense les compétences qui doivent exister dans le jeu, avant leur saisie dans
> `claude_rpg/data/skills.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md).

## Règles générales

- Une compétence dépend d'**un attribut** (Athlétisme → Force…).
- **Test** : d20 + modificateur de l'attribut + bonus de maîtrise si la compétence est maîtrisée, contre un DD. Un 20
  naturel réussit toujours, un 1 naturel échoue toujours.
- **Maîtrise** : elle vient de la classe (le joueur choisit 2 compétences, 4 pour le Roublard, dans la liste de sa
  classe, à la création), du passé ou d'un don. Une compétence déjà donnée par le passé ne peut pas être choisie
  en plus : on en prend une autre.
- **Expertise** : bonus de maîtrise doublé, dans des compétences maîtrisées choisies (Roublard, niveaux 1 et 6).
- **Avantage** : certaines aptitudes donnent l'avantage à une compétence (Athlète remarquable du Champion :
  Athlétisme ; Furtivité suprême du Voleur : Discrétion).
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
- **Maîtrisée par** : au choix pour Guerrier, Roublard ; passés Sauvageon, Soldat ; dons Athlète ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.

### Dextérité

### Acrobaties (`acrobatics`)

- **Attribut** : DEX.
- **Sert à** : garder l'équilibre, esquiver, faire des cabrioles.
- **Maîtrisée par** : au choix pour Guerrier, Roublard ; passés Saltimbanque ; dons Agile ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.

### Escamotage (`sleight_of_hand`)

- **Attribut** : DEX.
- **Sert à** : voler à la tire, crocheter, glisser un objet discrètement.
- **Maîtrisée par** : au choix pour Roublard ; passés Charlatan, Gamin des rues ; don Doué (au choix).
- **Usages actuels** : 1 test d'événement.

### Discrétion (`stealth`)

- **Attribut** : DEX.
- **Sert à** : se cacher, suivre quelqu'un, passer inaperçu.
- **Maîtrisée par** : au choix pour Roublard ; passés Criminel, Gamin des rues ; don Doué (au choix).
- **Usages actuels** : 3 tests d'événements.

### Intelligence

### Arcanes (`arcana`)

- **Attribut** : INT.
- **Sert à** : reconnaître la magie, les sorts, les objets enchantés, les créatures surnaturelles.
- **Maîtrisée par** : au choix pour Magicien ; passés Érudit ; don Doué (au choix).
- **Usages actuels** : 4 tests d'événements.

### Histoire (`history`)

- **Attribut** : INT.
- **Sert à** : se souvenir des événements passés, des lignées, des légendes.
- **Maîtrisée par** : au choix pour Guerrier, Magicien ; passés Noble, Érudit ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.
- **Notes** : idéale pour la chronique des vies passées (reconnaître la tombe d'un ancien personnage…).

### Investigation (`investigation`)

- **Attribut** : INT.
- **Sert à** : chercher des indices, déduire, repérer un mécanisme.
- **Maîtrisée par** : au choix pour Magicien, Roublard ; dons Artisan accompli ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.

### Nature (`nature`)

- **Attribut** : INT.
- **Sert à** : connaître plantes, animaux, terrain et météo.
- **Maîtrisée par** : au choix pour Magicien ; dons Érudit des arcanes ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.

### Religion (`religion`)

- **Attribut** : INT.
- **Sert à** : connaître les dieux, les rites, les morts-vivants et les êtres divins.
- **Maîtrisée par** : au choix pour Magicien ; passés Acolyte ; don Doué (au choix).
- **Usages actuels** : 1 test d'événement.

### Sagesse

### Dressage (`animal_handling`)

- **Attribut** : SAG.
- **Sert à** : calmer, monter ou dresser un animal.
- **Maîtrisée par** : au choix pour Guerrier ; passés Héros du peuple ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.
- **Notes** : utile pour les voyages (montures) et les compagnons animaux.

### Médecine (`medicine`)

- **Attribut** : SAG.
- **Sert à** : soigner, diagnostiquer, stabiliser un mourant.
- **Maîtrisée par** : au choix pour Magicien ; dons Guérisseur ; don Doué (au choix).
- **Usages actuels** : 2 tests d'événements.

### Perception (`perception`)

- **Attribut** : SAG.
- **Sert à** : repérer, entendre, sentir le danger.
- **Maîtrisée par** : au choix pour Guerrier, Roublard ; don Doué (au choix).
- **Usages actuels** : 1 test d'événement.

### Perspicacité (`insight`)

- **Attribut** : SAG.
- **Sert à** : deviner les intentions, déceler un mensonge.
- **Maîtrisée par** : au choix pour Guerrier, Magicien, Roublard ; passés Acolyte, Artisan ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.

### Survie (`survival`)

- **Attribut** : SAG.
- **Sert à** : pister, s'orienter, chasser, trouver un abri.
- **Maîtrisée par** : au choix pour Guerrier ; passés Héros du peuple, Sauvageon ; don Doué (au choix).
- **Usages actuels** : 1 test d'événement.
- **Notes** : centrale pour les voyages (se perdre ou non).

### Charisme

### Intimidation (`intimidation`)

- **Attribut** : CHA.
- **Sert à** : menacer, impressionner, faire plier.
- **Maîtrisée par** : au choix pour Guerrier, Roublard ; passés Soldat ; don Doué (au choix).
- **Usages actuels** : 2 tests d'événements.

### Persuasion (`persuasion`)

- **Attribut** : CHA.
- **Sert à** : convaincre, négocier, séduire.
- **Maîtrisée par** : au choix pour Roublard ; passés Artisan, Noble ; dons Langue d'argent ; don Doué (au choix).
- **Usages actuels** : 3 tests d'événements.
- **Notes** : servira aux prix des boutiques et aux relations sociales.

### Représentation (`performance`)

- **Attribut** : CHA.
- **Sert à** : chanter, jouer, conter, divertir une foule.
- **Maîtrisée par** : passés Saltimbanque ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.
- **Notes** : un métier possible (barde de taverne).

### Tromperie (`deception`)

- **Attribut** : CHA.
- **Sert à** : mentir, se déguiser, bluffer.
- **Maîtrisée par** : au choix pour Roublard ; passés Charlatan, Criminel ; don Doué (au choix).
- **Usages actuels** : aucun test d'événement pour l'instant.

---

## Compétences de métier (ajoutées le 2026-10-13)

Elles existent dans le jeu ; aucune classe ni aucun passé ne les maîtrise encore, et la fabrication ne les teste pas
encore (ce sera fait avec les métiers).

### Artisanat (`crafting`)

- **Attribut** : INT (à confirmer).
- **Sert à** : créer des objets « utiles » : armes, armures, outils, meubles…
- **Maîtrisée par** : dons Artisan accompli ; don Doué (au choix).
- **Usages prévus** : fabrication à la forge, métiers d'artisan.

### Arts (`arts`)

- **Attribut** : CHA (à confirmer).
- **Sert à** : réaliser des objets ou des prestations « agréables » : peindre, chanter, sculpter, jouer…
- **Maîtrisée par** : dons Musicien ; don Doué (au choix).
- **Usages prévus** : métiers d'artiste, revenus en taverne, relations sociales.
- **Notes** : recoupe Représentation ; faut-il fusionner les deux ?

### Potions et cuisine (`potions_cooking`)

- **Attribut** : SAG (à confirmer).
- **Sert à** : cuisiner, préparer des recettes alchimiques (potions, remèdes, poisons).
- **Maîtrisée par** : don Doué (au choix).
- **Usages prévus** : alchimie chez l'herboriste, cuisine, métiers.

---

## Compétences candidates (à compléter)

### Commerce

- **Attribut** : CHA ou INT ?
- **Sert à** : acheter et vendre au meilleur prix, tenir une boutique (aujourd'hui, c'est la Persuasion).

### Équitation / Conduite

- **Attribut** : DEX ou SAG ?
- **Sert à** : montures et attelages pendant les voyages.

---

## Décisions (2026-10-13)

- **Métiers** : trois compétences génériques plutôt qu'une par métier : **Artisanat**, **Arts**, **Potions et
  cuisine** (ajoutées).
- **Progression** : pas par la pratique ; plutôt liée à l'XP et à la montée de niveau. Solution à trouver, puisque
  dans D&D une compétence est seulement maîtrisée ou non.
- **Choix à la création** : oui, le joueur choisit ses compétences de classe (fait).

## Questions ouvertes

1. **Compétences en combat** : lesquelles ? (à retravailler avec les compétences en général)
2. **Attributs des nouvelles compétences** : Artisanat (INT), Arts (CHA), Potions et cuisine (SAG), ça te va ?
3. **Arts et Représentation** : on fusionne ?
4. **Progression des compétences** : quel système, au-delà de « maîtrisée ou non » (rangs de maîtrise, points à
   répartir en montant de niveau…) ?
