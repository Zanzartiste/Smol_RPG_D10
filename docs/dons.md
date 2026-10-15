# Catalogue des dons — Lifantasy

> Document de conception : il recense les dons qui doivent exister dans le jeu, avant leur saisie dans
> `claude_rpg/data/feats.json`. Les champs techniques (prérequis, modificateurs) sont détaillés dans
> [modele_donnees.md](modele_donnees.md), rubriques Dons et Modificateurs.

## Règles générales

- **Comment on obtient un don** :
  - **Passé** : chaque passé en accorde un dès la création (un don « d'origine »).
  - **Espèce** : l'humain choisit un don supplémentaire au début de la partie.
  - **Classe** : le don de classe, au niveau 1.
  - **Niveau** : la source principale des dons généraux. Les niveaux qui en donnent restent à placer dans la courbe
    de progression (`rules.json › advancement › feat_levels`, vide pour l'instant).
  - **Options de création** : à venir.
  - **Événement** : en règle générale, non (l'effet `add_feat` existe, à réserver aux exceptions).
- Quatre catégories :
  - **Origine** : dons de départ, liés aux passés (et le don en plus de l'humain) ;
  - **Classe** : chaque classe octroie un don « de classe » au niveau 1, qui détermine certaines capacités du
    personnage ;
  - **Général** : dons de niveau, parfois avec des prérequis ;
  - **Style de combat** : obtenus seulement par le don de classe Style de combat (Guerrier).
- **Dons à options** : certains demandent un choix (compétences, élément, sorts…), proposé au hub dès qu'on obtient
  le don (voir le système de choix dans [modele_donnees.md](modele_donnees.md)).
- Un don ne se prend qu'une fois, sauf exception indiquée.
- **Pas de gain d'attribut par un don** (décision du 2026-10-15).
- Ce qu'un don peut faire aujourd'hui :
  - bonus d'Armure, d'Esquive naturelle, d'initiative, de PV, au seuil des dégâts ou en dés au toucher avec une
    arme, en dés pour résister ;
  - rangs de compétence ;
  - résistance, immunité ou vulnérabilité à un type de dégâts, immunité à un état.

  Il peut aussi donner des **actions de combat** (Empoignade, Rage) et des **sorts** utilisables une fois par repos
  long (Initié à la magie).

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Catégorie** : origine / classe / général / style de combat.
- **Prérequis** : aucun / attribut minimum / classe / niveau…
- **Effet** : ce que le don fait, en une ou deux phrases.
- **Obtenu par** : passé X, montée de niveau, événement…
- **Notes** : …
```

---

## Dons d'origine (implémentés)

### Initié à la magie (`magic_initiate`)

- **Catégorie** : origine (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : Vous avez appris deux tours de magie et un sort du 1er niveau, que vous pouvez lancer une fois par repos long sans emplacement.
- **Détail** : au choix : l'attribut d'incantation parmi Intelligence, Sagesse, Charisme (compétence d'incantation : Érudition, Détermination ou Arts) ; au choix : 2 parmi : Trait de feu, Rayon de givre ; au choix : 1 parmi : Projectile magique, Mains brûlantes, Sommeil, Bouclier, Appel du familier ; une utilisation par repos long.
- **Obtenu par** : don de l'humain.

### Frappe brutale (`savage_attacker`)

- **Catégorie** : origine (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : Une fois par tour, quand vous touchez avec une arme, vous lancez ses dés de dégâts deux fois et gardez le meilleur résultat.
- **Détail** : une fois par tour, dés de dégâts d'arme lancés deux fois (le meilleur est gardé).
- **Obtenu par** : passé Soldat, don de l'humain.

### Doué (`skilled`)

- **Catégorie** : origine (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : +1 rang dans trois compétences de votre choix.
- **Détail** : au choix : +1 rang dans 3 compétence(s) au choix.
- **Obtenu par** : passé Noble, don de l'humain.

### Robuste (`tough`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Votre endurance est hors du commun.
- **Détail** : +3 PV (une fois ; les PV ne montent plus avec le niveau).
- **Obtenu par** : passé Héros du peuple, don de l'humain.

### Guérisseur (`healer`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Vous savez panser les plaies du corps comme celles de l'âme.
- **Détail** : +1 rang en Médecine.
- **Obtenu par** : passé Acolyte, don de l'humain.

### Artisan accompli (`crafter`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Un œil exercé repère la moindre malfaçon… et le moindre détail suspect.
- **Détail** : +1 rang en Artisanat ; +1 rang en Perception.
- **Obtenu par** : passé Artisan, don de l'humain.

### Langue d'argent (`silver_tongue`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Vous trouvez toujours les mots, surtout ceux qui ne sont pas vrais.
- **Détail** : +1 rang en Persuasion.
- **Obtenu par** : passé Charlatan, don de l'humain.

### Musicien (`musician`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Votre talent apaise les foules et vous ouvre bien des portes.
- **Détail** : +1 rang en Arts.
- **Obtenu par** : passé Saltimbanque, don de l'humain.

### Athlète (`athlete`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Un entraînement physique rigoureux a forgé votre corps.
- **Détail** : +1 rang en Physique.
- **Obtenu par** : passé Sauvageon, don de l'humain.

### Érudit des arcanes (`scholar`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Des nuits entières passées sur les grimoires ont aiguisé votre esprit.
- **Détail** : +1 rang en Érudition.
- **Obtenu par** : passé Érudit, don de l'humain.

### Agile (`nimble`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Les ruelles vous ont appris à esquiver, sauter et filer.
- **Détail** : +1 rang en Physique.
- **Obtenu par** : passés Gamin des rues et Criminel, don de l'humain.

---

## Dons généraux (implémentés)

### Lutteur (`grappler`)

- **Catégorie** : général (SRD 5.2).
- **Prérequis** : niveau 4, Force 13 ou Dextérité 13.
- **Effet** : Vous savez frapper et empoigner d'un même geste : l'Empoignade entrave la cible.
- **Détail** : action : Empoignade.
- **Obtenu par** : niveau (à placer).

### Duelliste défensif (`defensive_duelist`)

- **Catégorie** : général.
- **Prérequis** : Dextérité 13.
- **Effet** : Vous savez parer les coups grâce à votre agilité.
- **Détail** : +1 Esquive naturelle (système d10).
- **Obtenu par** : niveau (à placer).

### Résistant (`resilient`)

- **Catégorie** : général.
- **Prérequis** : aucun.
- **Effet** : un dé de plus pour résister avec l'attribut choisi.
- **Détail** : au choix : 1 attribut parmi : n'importe quel attribut.
- **Obtenu par** : niveau (à placer).

### Adepte élémentaire (`elemental_adept`)

- **Catégorie** : général.
- **Prérequis** : classe : Magicien.
- **Effet** : Vos sorts ignorent la résistance de vos cibles à l'élément choisi.
- **Détail** : au choix : un élément parmi : Feu, Froid, Foudre, Tonnerre.
- **Obtenu par** : niveau (à placer).

### Entraînement aux armures lourdes (`heavy_armor_training`)

- **Catégorie** : général.
- **Prérequis** : niveau 4.
- **Effet** : Les armures vous pèsent moins : leur Force conseillée baisse de 2.
- **Détail** : Force conseillée des armures −2.
- **Obtenu par** : niveau (à placer).

---

## Dons de classe (implémentés)

Un par classe, obtenu au niveau 1 (tableur [Classes.ods](Classes.ods)). Dans le jeu, ce sont les aptitudes de
niveau 1 des classes (`classes.json › features`).

### Style de combat (`fighting_style`)

- **Catégorie** : classe (Guerrier).
- **Effet** : vous choisissez un don de style de combat : à une main, à mains nues, à deux armes, à deux mains ou à
  distance.

### Attaques précises (`precise_attacks`)

- **Catégorie** : classe (Roublard).
- **Effet** : vos attaques critiques infligent 3 dés de dégâts supplémentaires.

### Rage (`rage`)

- **Catégorie** : classe (Barbare).
- **Effet** : action gratuite, jusqu'au début de votre prochain tour : vous ne pouvez plus qu'attaquer au corps à
  corps, et les succès des jets d'attaque que vous faites et que vous subissez sont doublés.

### Sorts arcaniques (`arcane_spells`)

- **Catégorie** : classe (Magicien).
- **Effet** : vous lancez des sorts en puisant dans vos connaissances ésotériques de la magie ; ils utilisent la
  compétence Érudition (INT).

### Dons de classe prévus (classes pas encore implémentées)

- **Traque** (Rôdeur) : vous choisissez un ennemi ; tant que vous le traquez, tous vos jets qui le concernent ont un
  bonus de +1 (attaque…).
- **Sorts de druide** (Druide) : sorts tirés des pouvoirs de la nature, avec la compétence Nature (SAG).
- **Sorts divins** (Clerc) : sorts tirés d'une divinité ou d'un domaine divin, avec la compétence Détermination
  (SAG).
- **Représentations bardiques** (Barde) : sorts tirés des talents artistiques, avec la compétence Arts (CHA ou
  DEX).

---

## Styles de combat (implémentés)

Obtenus par le don de classe Style de combat (Guerrier niveau 1, Champion niveau 7).

### Style : À une main (`dueling`)

- **Effet** : un dé de dégâts de plus avec une arme de corps à corps tenue à une main, sans arme dans l'autre main
  (un bouclier est permis).

### Style : À mains nues (`unarmed_fighting`)

- **Effet** : un dé de dégâts de plus avec vos attaques à mains nues.

### Style : À deux armes (`two_weapon_fighting`)

- **Effet** : l'attaque de la main secondaire n'a pas de malus. (Règle pour tous : avec une arme de corps à corps à
  une main dans chaque main, chaque attaque de l'arme principale est suivie d'une attaque de la seconde arme, avec
  ses propres jets, à deux dés de moins à l'attaque et aux dégâts : `rules.json › combat › off_hand_penalty`.)

### Style : À deux mains (`great_weapon_fighting`)

- **Effet** : avec une arme tenue à deux mains, vous relancez une fois les dés de dégâts ratés.

### Style : À distance (`archery`)

- **Effet** : un dé de plus aux attaques avec une arme à distance.

---

## Dons candidats (à compléter)

### Idées tirées de l'ancienne progression des classes (SRD)

Retirées des classes le 2026-10-15 ; leurs mécaniques existent encore dans le code (modificateurs, actions,
ressources), prêtes à devenir des dons.

- **Fougue** (ex-Guerrier 2) : une fois par combat, une action de plus pendant son tour (action `action_surge`).
- **Attaque supplémentaire** (ex-Guerrier 5, 11, 20) : l'action Attaque frappe une fois de plus (`extra_attack`).
- **Inflexible** (ex-Guerrier 9, 13, 17) : relance automatique d'une résistance ratée, par repos long (ressource
  `indomitable`).
- **Attaque sournoise** (ex-Roublard) : une attaque qui gagne des dés de dégâts avec le niveau (action
  `sneak_attack`).
- **Ruse** (ex-Roublard 2) : Se cacher ne coûte pas d'action, une fois par tour (`cunning_action`).
- **Esquive instinctive** (ex-Roublard 5) : une attaque par round fait moitié moins de dégâts (`uncanny_dodge`).
- **Expertise** (ex-Roublard 1 et 6) : +1 rang dans deux compétences déjà entraînées.
- **Dérobade** (ex-Roublard 7) : en résistant avec la DEX à des dégâts, chaque succès en retire deux (`evasion`).
- **Talent fiable** (ex-Roublard 11) : au moins un succès avec une compétence entraînée (`reliable_talent`).
- **Sorts appris** (ex-Magicien 2 à 10) : un nouveau sort au choix parmi ceux qu'on peut lancer.

### Chanceux

- **Catégorie** : origine ou général.
- **Effet envisagé** : quelques relances de dés ratés par repos long.

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
  simplifiée (Initié à la magie, Frappe brutale, Doué, Lutteur).
- **Dons à choix** (Doué, Résistant, Adepte élémentaire…) : oui, avec un écran de choix (fait).
- **Dons qui donnent des actions ou des sorts** : possible.

## Décisions (2026-10-15)

- +1 attribut aux niveaux 5, 10, 15 et 20 (tableur). Les dons de niveau restent la source principale des dons
  généraux ; leurs niveaux sont à placer. Pas de don par événement en règle générale.
- Aucun don ne donne d'attribut ; le don Amélioration d'attribut est supprimé.
- Vigilant est supprimé (le passé Criminel donne Agile) ; le style Défense aussi (absent de la liste du tableur).
- Les dons de classe sont les aptitudes de niveau 1 des classes.

## Questions ouvertes

1. **Dons de métier** : pas certain, à voir avec les métiers.
