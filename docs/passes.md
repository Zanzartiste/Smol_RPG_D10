# Catalogue des passés — Lifantasy

> Document de conception : c'est ici qu'on décrit les passés (ce que faisait le personnage avant l'aventure) avant de
> les saisir dans `claude_rpg/data/backgrounds.json`. Les champs techniques sont dans
> [modele_donnees.md](modele_donnees.md) ; les dons d'origine sont dans [dons.md](dons.md).

## Règles actuelles

- On choisit un passé à la création.
- Il donne **4 rangs de compétence** (1 rang dans 4 compétences, fixes) et **un don d'origine au choix parmi 5**
  (source : feuilles `PastsCompAtRankOne` et `Dons` de [Classes.ods](Classes.ods)). Pas d'or ni d'objet de passé
  pour l'instant. **Implémenté.**
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

- **Quartier de départ** (`start_district`, quartiers dans `rules.json › districts`) : port (Marin, Pirate,
  Contrebandier), fermes (Fermier, Vagabond, Héros du peuple), temple (Acolyte), cabane en forêt (Ermite), place du
  marché (les autres). La vie y commence ; le marqueur `district_<id>` permet des événements propres au quartier.

## Catalogue

Toutes les compétences sont à +1. Statut : disponible, sauf mention contraire.

### Marin (`sailor`)

- **Compétences** : Physique, Détermination, Perception, Nature.
- **Dons au choix** : Aquatique, Orientation, Tacticien, Agile, Bagarreur de taverne.

### Soldat (`soldier`)

- **Compétences** : Armes de mêlée, Armes de trait, Physique, Détermination.
- **Dons au choix** : Vigilant, Costaud, Tacticien, Frappe brutale, Citadin.

### Érudit (`scholar`)

- **Compétences** : Langues, Érudition, Alchimie, Médecine.
- **Dons au choix** : Intuition mystique, Malin, Linguiste, Initié à la magie (magicien), Artisan accompli.

### Vagabond (`wanderer`)

- **Compétences** : Physique, Détermination, Nature, Dressage.
- **Dons au choix** : Affinité naturelle, Adapté au climat, Orientation, Initié à la magie (druide), Vigoureux.

### Enfant des rues (`urchin`)

- **Compétences** : Persuasion, Escamotage, Furtivité, Perception.
- **Dons au choix** : Orientation, Perspicace, Chanceux, Robuste, Citadin.

### Artiste (`artist`)

- **Compétences** : Langues, Persuasion, Perspicacité, Arts.
- **Dons au choix** : Charmeur, Rusé, Joueur, Musicien, Artisan accompli.

### Artisan (`artisan`)

- **Compétences** : Machines, Persuasion, Perception, Artisanat.
- **Dons au choix** : Malin, Artisan accompli, Musicien, Agile, Citadin.

### Criminel (`criminal`)

- **Compétences** : Physique, Escamotage, Furtivité, Perception.
- **Dons au choix** : Vigilant, Rusé, Joueur, Agile, Citadin.

### Acolyte (`acolyte`)

- **Compétences** : Détermination, Perspicacité, Érudition, Médecine.
- **Dons au choix** : Doué, Guérisseur, Intuition mystique, Perspicace, Initié à la magie.

### Noble (`noble`)

- **Compétences** : Langues, Persuasion, Érudition, Arts.
- **Dons au choix** : Tacticien, Charmeur, Linguiste, Musicien, Doué.

### Marchand (`merchant`)

- **Compétences** : Langues, Persuasion, Perspicacité, Dressage.
- **Dons au choix** : Malin, Artisan accompli, Linguiste, Chanceux, Doué.

### Courtier (`courtier`)

- **Compétences** : Persuasion, Perspicacité, Érudition, Arts.
- **Dons au choix** : Malin, Artisan accompli, Musicien, Citadin, Linguiste.

### Fermier (`farmer`)

- **Compétences** : Physique, Détermination, Nature, Dressage.
- **Dons au choix** : Artisan accompli, Adapté au climat, Bagarreur de taverne, Robuste, Vigoureux.

### Ermite (`hermit`)

- **Compétences** : Érudition, Médecine, Nature, Dressage.
- **Dons au choix** : Artisan accompli, Guérisseur, Perspicace, Initié à la magie (druide), Affinité naturelle.

### Pirate (`pirate`)

- **Compétences** : Machines, Physique, Détermination, Escamotage.
- **Dons au choix** : Aquatique, Bagarreur de taverne, Agile, Joueur, Rusé.

### Gladiateur (`gladiator`)

- **Compétences** : Armes de mêlée, Physique, Détermination, Arts.
- **Dons au choix** : Costaud, Frappe brutale, Tacticien, Robuste, Bagarreur de taverne.

### Contrebandier (`smuggler`)

- **Compétences** : Persuasion, Furtivité, Nature, Dressage.
- **Dons au choix** : Charmeur, Rusé, Joueur, Chanceux, Affinité naturelle.

### Sur mesure (`custom`)

- **Statut** : disponible pour l'instant, **à bloquer plus tard**.
- **Compétences** : 4 compétences au choix parmi toutes (+1 chacune, 4 différentes).
- **Don** : un don au choix parmi tous les dons d'origine.

## Pistes de nouveaux passés (proposées par Claude, à valider)

- **Chasseur** (`hunter`) : A. Trait, Furtivité, Nature, Perception — Vigilant, Affinité naturelle, Orientation, Frappe brutale, Adapté au climat.
- **Mercenaire** (`mercenary`) : A. Mêlée, Physique, Persuasion, Perspicacité — Costaud, Tacticien, Robuste, Bagarreur de taverne, Vigilant.
- **Apprenti alchimiste** (`apprentice_alchemist`) : Alchimie, Médecine, Nature, Érudition — Artisan accompli, Guérisseur, Malin, Affinité naturelle, Initié à la magie.
- **Mineur** (`miner`) : Physique, Machines, Artisanat, Détermination — Costaud, Robuste, Vigoureux, Orientation, Artisan accompli.
- **Espion** (`spy`) : Furtivité, Langues, Perspicacité, Persuasion — Rusé, Linguiste, Vigilant, Charmeur, Chanceux.
- **Pèlerin** (`pilgrim`) : Détermination, Langues, Nature, Perspicacité — Orientation, Adapté au climat, Intuition mystique, Perspicace, Vigoureux.
- **Exilé** (`exile`), à débloquer : Furtivité, Nature, Langues, Physique — Chanceux, Adapté au climat, Orientation, Robuste, Rusé.
- **Ancien esclave** (`freed_slave`), à débloquer : Physique, Détermination, Escamotage, Perspicacité — Robuste, Vigoureux, Rusé, Perspicace, Bagarreur de taverne.

### Charlatan (`charlatan`)

- **Compétences** : Persuasion, Escamotage, Perspicacité, Arts.
- **Dons au choix** : Charmeur, Rusé, Joueur, Linguiste, Chanceux.

### Héros du peuple (`folk_hero`)

- **Compétences** : Armes de mêlée, Physique, Nature, Dressage.
- **Dons au choix** : Costaud, Robuste, Vigoureux, Tacticien, Affinité naturelle.

Ids conservés des anciens passés : Érudit `sage`, Vagabond `outlander`, Enfant des rues `urchin`, Artiste `entertainer`.

## Décisions (2026-10-16, reprises de questions_suite.md)

- Saltimbanque est devenu Artiste ; Charlatan et Héros du peuple sont adaptés au système du tableur (fait).
- Courtier : 5e don au choix = Linguiste (fait). Gladiateur : « Tactical Mind » = Tacticien.
- Les pistes de passés (Chasseur, Mercenaire, Espion…) restent de simples pistes.
- Pas d'or ni d'objet de départ propre à chaque passé pour l'instant.
- Sur mesure sera débloqué par un succès, à choisir plus tard (pas prioritaire).
- Lieu de départ : un quartier de la ville selon le passé (fait, surtout pour tester) ; une vie commence le matin.
