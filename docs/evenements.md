# Événements — Lifantasy

> Document de conception : comment écrire les événements (le cœur narratif du jeu) et le catalogue de ceux à créer,
> avant de les saisir dans `claude_rpg/data/events/*.json`. Les champs techniques (conditions, effets, tests) sont
> dans [modele_donnees.md](modele_donnees.md).

## Ce qui existe

- **29 événements** répartis en trois pools : forêt (14), ville (11), domicile (4).
- Un événement a un texte, des choix (avec conditions et tests de compétence), des effets (or, XP, objets, états,
  combat, relations, quêtes, journal…), et un poids de tirage.
- Des choix verrouillés sont cachés (visibles grisés en mode debug).
- Des événements de Survie (se perdre), des demandes de PNJ générées, des rencontres de combat.

## Questions à trancher

### 1. Le ton

- Plutôt sérieux et sombre (BG3), léger et absurde, ou un mélange (événements quotidiens légers, aventures graves) ?
- Deuxième personne (« Vous trouvez… ») : on garde ?
- Longueur visée d'un texte : 2–3 phrases, ou des scènes plus longues en plusieurs pages ?

### 2. Le tirage

- Combien d'événements par pool pour que la répétition ne se voie pas ? (Viser 30 à 50 par lieu ?)
- Un événement déjà vu peut-il revenir ? Après combien de temps ?
- Des **chaînes d'événements** (suite qui arrive quelques jours plus tard) : déjà possibles par les faits et les
  quêtes ; à généraliser ?
- Des événements **rares** ou **uniques au monde** (une seule fois, toutes vies confondues) ?

### 3. Les choix

- Toujours un choix « sans risque » pour sortir ?
- Combien de choix au plus (3 ? 5 ?) ?
- Afficher la compétence et la difficulté du test sur le bouton (« [Furtivité, difficulté 2] ») ou les cacher ?
- Montrer les choix verrouillés en jeu normal (pour donner envie) ou les cacher (actuel) ?

### 4. Les conséquences

- Des conséquences **différées** (un choix aujourd'hui, une suite dans un an) ?
- Des conséquences sur le monde (un lieu change, un PNJ meurt, une faction gagne du pouvoir) ?
- Quelle part d'événements mortels ? La mort peut-elle venir d'un événement sans combat ?

### 5. Les étapes de la vie

- Des événements propres à chaque âge (jeunesse, âge adulte, vieillesse) ? Lesquels manquent le plus ?
- Des événements de saison, de météo, de fête (calendrier) ?
- Des événements liés à l'espèce, la classe, le passé, la réputation, les traits ?

### 6. Les nouveaux lieux

Quels pools ajouter en priorité ? Pistes : taverne, mine, route, rivière, montagne, ruines, temple, marché, port,
autre ville. Chacun a-t-il ses PNJ, ses boutiques, son terrain de combat ?

## Modèle de fiche (à copier)

Pour proposer un événement sans écrire de JSON :

```markdown
### <Titre> (`<id>`)

- **Lieu** : forêt / ville / domicile / …
- **Conditions** : âge, saison, classe, quête en cours, fait connu…
- **Texte** : …
- **Choix** :
  - <Choix 1> — test (compétence, difficulté) ; réussite : … ; échec : …
  - <Choix 2> — …
- **Suite** : chaîne, quête, fait enregistré…
```

## Catalogue des idées

À remplir au fil de l'eau (des événements de test peuvent être générés au besoin).
