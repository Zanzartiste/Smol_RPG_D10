# Catalogue des passés — Lifantasy

> Document de conception : c'est ici qu'on décrit les passés (ce que faisait le personnage avant l'aventure) avant de
> les saisir dans `claude_rpg/data/backgrounds.json`. Les champs techniques sont dans
> [modele_donnees.md](modele_donnees.md) ; les dons d'origine sont dans [dons.md](dons.md).

## Règles actuelles

- On choisit un passé à la création.
- Il donne **4 rangs de compétence** (1 rang dans 4 compétences) et un **don d'origine**.
- Certains donnent de l'or en plus (Noble : 25 po).
- La description peut s'accorder au genre (`{g:masculin|féminin|neutre}`).

## Questions à trancher

1. **Que doit apporter un passé en plus ?** Pistes :
   - de l'équipement de départ ou de l'or (quand l'équipement s'achètera à la création) ;
   - des relations de départ (un ancien maître, un rival, un contact dans la pègre) ;
   - de la réputation dans un lieu ou une faction (le Noble est connu, le Criminel recherché) ;
   - des événements réservés (le Soldat retrouve un ancien frère d'armes, l'Acolyte est appelé au temple) ;
   - une langue ;
   - un lieu de départ différent.
2. **Passés liés à l'espèce ou à la région ?** Un passé « Nomade des steppes » réservé à une région, ou tous les
   passés ouverts à tous ?
3. **Passés à débloquer** (par un succès en jeu, comme les classes) ?
4. **Passé et vies précédentes** : plus tard (voir [creation_personnage.md](creation_personnage.md)).
5. **Choix dans le passé** : les 4 compétences sont-elles fixes, ou « 2 fixes + 2 au choix parmi 4 » ?
6. **Le passé peut-il changer** pendant la vie (un soldat qui déserte devient criminel) ? Probablement non : le passé
   est figé, ce sont les métiers et la réputation qui évoluent.

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Concept** : une phrase.
- **Statut** : disponible / à débloquer (succès à réussir).
- **Compétences** : 4 rangs (ex. Furtivité +1, Persuasion +1…).
- **Don d'origine** : …
- **Bonus** : or, objets, langue, relation, réputation…
- **Événements liés** : …
- **Description** : le texte affiché à la création.
```

## Catalogue

### Acolyte (`acolyte`)

- **Compétences** : Érudition, Perspicacité, Médecine, Détermination.
- **Don d'origine** : Guérisseur (`healer`).
- **Description** : Vous avez grandi au service d'un temple, entre prières et rites.

### Artisan (`artisan`)

- **Compétences** : Artisanat, Perspicacité, Persuasion, Perception.
- **Don d'origine** : Artisan accompli (`crafter`).
- **Description** : Membre d'une guilde, vous connaissez la valeur du travail bien fait et des contrats bien négociés.

### Charlatan (`charlatan`)

- **Compétences** : Persuasion, Escamotage, Perspicacité, Arts.
- **Don d'origine** : Langue d'argent (`silver_tongue`).
- **Description** : Faux remèdes, fausses identités, vrais profits. Vous savez vendre n'importe quoi.

### Criminel (`criminal`)

- **Compétences** : Furtivité, Persuasion, Escamotage, Perception.
- **Don d'origine** : Agile (`nimble`).
- **Description** : Vous avez vécu de l'autre côté de la loi, et vous en connaissez encore les ficelles.

### Saltimbanque (`entertainer`)

- **Compétences** : Arts, Physique, Persuasion, Langues.
- **Don d'origine** : Musicien (`musician`).
- **Description** : Acrobate, musicien ou conteur, vous avez fait rire et pleurer bien des tavernes.

### Héros du peuple (`folk_hero`)

- **Compétences** : Nature, Dressage, Physique, Armes de mêlée.
- **Don d'origine** : Robuste (`tough`).
- **Description** : Simple villageois, vous vous êtes un jour dressé contre l'injustice. On s'en souvient encore.

### Noble (`noble`)

- **Compétences** : Persuasion, Érudition, Langues, Perspicacité.
- **Don d'origine** : Doué (`skilled`).
- **Bonus** : 25 po.
- **Description** : Né dans la soie, vous connaissez l'étiquette, les lignées et le pouvoir d'un nom.

### Sauvageon (`outlander`)

- **Compétences** : Nature, Physique, Perception, Dressage.
- **Don d'origine** : Athlète (`athlete`).
- **Description** : Vous avez grandi loin des villes, au rythme des saisons et des bêtes sauvages.

### Érudit (`sage`)

- **Compétences** : Érudition, Langues, Alchimie, Détermination.
- **Don d'origine** : Érudit des arcanes (`scholar`).
- **Description** : Des années passées dans les bibliothèques ont fait de vous un puits de savoir.

### Soldat (`soldier`)

- **Compétences** : Physique, Armes de mêlée, Persuasion, Détermination.
- **Don d'origine** : Frappe brutale (`savage_attacker`).
- **Description** : Vous avez servi dans une armée. La discipline et le fracas des armes vous sont familiers.

### Gamin des rues (`urchin`)

- **Compétences** : Furtivité, Escamotage, Perception, Physique.
- **Don d'origine** : Agile (`nimble`).
- **Description** : Orphelin, vous avez survécu dans les ruelles grâce à vos doigts agiles et à votre discrétion.

## Idées de nouveaux passés

- Apprenti (d'un forgeron, d'un alchimiste, d'un mage) — lié aux métiers.
- Marin, pêcheur.
- Paysan, berger.
- Ermite.
- Marchand ambulant.
- Chasseur.
- Garde de la ville.
- Esclave affranchi, prisonnier évadé.
- Enfant d'un héros d'une vie précédente (plus tard).
