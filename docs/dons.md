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
- Trois catégories :
  - **Origine** : dons de départ, liés aux passés (et le don en plus de l'humain) ;
  - **Général** : dons qu'on choisit en montant de niveau, parfois avec des prérequis ;
  - **Style de combat** : obtenus seulement par l'aptitude Style de combat (Guerrier).
- **Dons à options** : certains demandent un choix (attribut, compétences, élément, sorts…), proposé au hub dès
  qu'on obtient le don (voir le système de choix dans [modele_donnees.md](modele_donnees.md)).
- Un don ne se prend qu'une fois.
- Ce qu'un don peut faire aujourd'hui :
  - bonus d'attribut, d'Armure, d'Esquive naturelle, d'initiative, de PV, au seuil des dégâts ou en dés au toucher
    avec une arme, en dés pour résister ;
  - rangs de compétence, dé de résistance ;
  - résistance, immunité ou vulnérabilité à un type de dégâts, immunité à un état.

  Il peut aussi donner des **actions de combat** (Empoignade) et des **sorts** utilisables une fois par repos long
  (Initié à la magie).
- ⚠️ Licence : le SRD 5.2 (2025, CC-BY 4.0) contient une partie des dons de D&D 2024 : ils sont implémentés dans
  leur version complète (marqués « SRD 5.2 »). Les autres sont nos propres versions.

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

- **Catégorie** : origine (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : Toujours sur le qui-vive : vous ajoutez votre bonus de maîtrise à l'initiative.
- **Détail** : bonus de maîtrise à l'initiative.
- **Obtenu par** : passé Criminel, don de l'humain.

### Initié à la magie (`magic_initiate`)

- **Catégorie** : origine (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : Vous avez appris deux tours de magie et un sort du 1er niveau, que vous pouvez lancer une fois par repos long sans emplacement.
- **Détail** : +1 rang en Magie ; au choix : 1 attribut(s) parmi : Intelligence, Sagesse, Charisme ; au choix : 2 parmi : Trait de feu, Rayon de givre ; au choix : 1 parmi : Projectile magique, Mains brûlantes, Sommeil, Bouclier, Appel du familier ; une utilisation par repos long.
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
- **Détail** : +1 SAG ; +1 rang en Médecine.
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
- **Détail** : +1 CHA ; +1 rang en Persuasion.
- **Obtenu par** : passé Charlatan, don de l'humain.

### Musicien (`musician`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Votre talent apaise les foules et vous ouvre bien des portes.
- **Détail** : +1 CHA ; +1 rang en Arts.
- **Obtenu par** : passé Saltimbanque, don de l'humain.

### Athlète (`athlete`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Un entraînement physique rigoureux a forgé votre corps.
- **Détail** : +1 rang en Physique ; au choix : 1 attribut(s) parmi : Force, Dextérité.
- **Obtenu par** : passé Sauvageon, don de l'humain.

### Érudit des arcanes (`scholar`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Des nuits entières passées sur les grimoires ont aiguisé votre esprit.
- **Détail** : +1 INT ; +1 rang en Érudition.
- **Obtenu par** : passé Érudit, don de l'humain.

### Agile (`nimble`)

- **Catégorie** : origine.
- **Prérequis** : aucun.
- **Effet** : Les ruelles vous ont appris à esquiver, sauter et filer.
- **Détail** : +1 DEX ; +1 rang en Physique.
- **Obtenu par** : passé Gamin des rues, don de l'humain.

---

## Dons généraux (implémentés)

### Amélioration d'attribut (`ability_score_improvement`)

- **Catégorie** : général (SRD 5.2).
- **Prérequis** : niveau 4.
- **Effet** : +2 à un attribut, ou +1 à deux attributs (20 au maximum).
- **Détail** : au choix : 2 attribut(s) parmi : n'importe quel attribut.
- **Obtenu par** : montée de niveau (4, 8, 12, 16, 20).

### Lutteur (`grappler`)

- **Catégorie** : général (SRD 5.2).
- **Prérequis** : niveau 4, Force 13 ou Dextérité 13.
- **Effet** : +1 FOR ou DEX. Vous savez frapper et empoigner d'un même geste : l'Empoignade entrave la cible.
- **Détail** : au choix : 1 attribut(s) parmi : Force, Dextérité ; action : Empoignade.
- **Obtenu par** : montée de niveau (4, 8, 12, 16, 20).

### Duelliste défensif (`defensive_duelist`)

- **Catégorie** : général.
- **Prérequis** : Dextérité 13.
- **Effet** : Vous savez parer les coups grâce à votre agilité.
- **Détail** : +1 Esquive naturelle (système d10).
- **Obtenu par** : montée de niveau (4, 8, 12, 16, 20).

### Résistant (`resilient`)

- **Catégorie** : général.
- **Prérequis** : aucun.
- **Effet** : +1 à un attribut, et un dé de plus pour résister avec cet attribut.
- **Détail** : au choix : 1 attribut(s) parmi : n'importe quel attribut.
- **Obtenu par** : montée de niveau (4, 8, 12, 16, 20).

### Adepte élémentaire (`elemental_adept`)

- **Catégorie** : général.
- **Prérequis** : classe : Magicien.
- **Effet** : +1 INT, SAG ou CHA. Vos sorts ignorent la résistance de vos cibles à l'élément choisi.
- **Détail** : au choix : un élément parmi : Feu, Froid, Foudre, Tonnerre ; au choix : 1 attribut(s) parmi : Intelligence, Sagesse, Charisme.
- **Obtenu par** : montée de niveau (4, 8, 12, 16, 20).

### Entraînement aux armures lourdes (`heavy_armor_training`)

- **Catégorie** : général.
- **Prérequis** : niveau 4.
- **Effet** : +1 FOR ou CON. Les armures vous pèsent moins : leur Force conseillée baisse de 2.
- **Détail** : Force conseillée des armures −2 ; au choix : 1 attribut(s) parmi : Force, Constitution.
- **Obtenu par** : montée de niveau (4, 8, 12, 16, 20).

---

## Styles de combat (implémentés)

### Style : Archerie (`archery`)

- **Catégorie** : style de combat (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : +2 aux jets d'attaque avec une arme à distance.
- **Détail** : +2 au toucher à distance.
- **Obtenu par** : aptitude Style de combat (Guerrier niveau 1, Champion niveau 7).

### Style : Défense (`defense`)

- **Catégorie** : style de combat (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : +1 Armure tant que vous portez une armure (pas de simples vêtements).
- **Détail** : +1 Armure en armure.
- **Obtenu par** : aptitude Style de combat (Guerrier niveau 1, Champion niveau 7).

### Style : Armes à deux mains (`great_weapon_fighting`)

- **Catégorie** : style de combat (SRD 5.2).
- **Prérequis** : aucun.
- **Effet** : Avec une arme tenue à deux mains, chaque 1 ou 2 sur un dé de dégâts compte comme un 3.
- **Détail** : à deux mains, 1 et 2 aux dés de dégâts comptent 3.
- **Obtenu par** : aptitude Style de combat (Guerrier niveau 1, Champion niveau 7).

### Style : Duel (`dueling`)

- **Catégorie** : style de combat.
- **Prérequis** : aucun.
- **Effet** : +2 aux dégâts avec une arme de corps à corps tenue à une main.
- **Détail** : +2 aux dégâts à une main (corps à corps).
- **Obtenu par** : aptitude Style de combat (Guerrier niveau 1, Champion niveau 7).

---

## Dons candidats (à compléter)

### Amélioration d'attribut

- **Catégorie** : général.
- **Effet envisagé** : +2 à un attribut, ou +1 à deux attributs (le don « par défaut » de D&D).

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
  simplifiée. Fait pour Vigilant, Initié à la magie, Frappe brutale, Doué, Lutteur, Amélioration d'attribut et
  les styles de combat ; Résistant, Adepte élémentaire, Athlète et Entraînement aux armures lourdes sont passés en
  version à options.
- **Dons à choix** (Doué, Résistant, Adepte élémentaire…) : oui, avec un écran de choix (fait).
- **Dons qui donnent des actions ou des sorts** : possible.
- **Tous les 4 niveaux** : un attribut **et** un don. On n'a jamais à choisir entre améliorer ses statistiques et
  développer son personnage avec un don intéressant.

## Questions ouvertes

1. **Dons de métier** : pas certain, à voir avec les métiers.
