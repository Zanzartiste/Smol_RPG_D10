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

- Plutôt sérieux et sombre (BG3), léger et absurde, ou un mélange (événements quotidiens légers, aventures graves) ? => Un mélange.
- Deuxième personne (« Vous trouvez… ») : on garde ? => Oui ? Sinon le système de BG3 avec le narrateur qui décrit en mode "There appears to be..." ou parfois les personnage eux même "j'ai repéré quelque chose par là".
- Longueur visée d'un texte : 2–3 phrases, ou des scènes plus longues en plusieurs pages ? => Peut être pas plusieurs pages mais des scènes de plus de 2-3 phrases sont possibles.

### 2. Le tirage

- Combien d'événements par pool pour que la répétition ne se voie pas ? (Viser 30 à 50 par lieu ?) => Certains seront en fonction des lieux, d'autres pourront se produire dans plusieurs endroits différents mais que le soir etc...
- Un événement déjà vu peut-il revenir ? Après combien de temps ? => Oui, ça dépend de l'évènement, recroiser une meute de loups semble probable, recroiser un seigneur vampire moins, à moins qu'on soit dans un château de vampire, auquel cas c'est l'inverse.
- Des **chaînes d'événements** (suite qui arrive quelques jours plus tard) : déjà possibles par les faits et les
  quêtes ; à généraliser ? => Oui j'aime bien.
- Des événements **rares** ou **uniques au monde** (une seule fois, toutes vies confondues) ? => Rares oui, pas uniques au monde à priori.

### 3. Les choix

- Toujours un choix « sans risque » pour sortir ? => Non du tout, si le PJ pouvait éviter d'aller dans les bois de la mort, il n'a pas nécessairement à avoir de porte de sortie pour s'enfuir s'il tombe sur des ennemis surpuissants (il peut toujours *tenter* de fuir le combat ou d'éviter un danger)
- Combien de choix au plus (3 ? 5 ?) ? (5 semble pas mal, s'il y en a plus, notamment en combat, il vaut mieux utiliser des menus à la Final Fantasy / Dragon Quest par exemple, ou des hotbars avec plusieurs icônes pour les différents sorts / attaques, plutôt qu'une liste de 50 options avec des phrases)
- Afficher la compétence et la difficulté du test sur le bouton (« [Furtivité, difficulté 2] ») ou les cacher ? => On doit pouvoir afficher/masquer le tout avec la proba, dans les options.
- Montrer les choix verrouillés en jeu normal (pour donner envie) ou les cacher (actuel) ? les cacher, sauf si une option est activée.

### 4. Les conséquences

- Des conséquences **différées** (un choix aujourd'hui, une suite dans un an) ? => Oui ça doit pouvoir être le cas.
- Des conséquences sur le monde (un lieu change, un PNJ meurt, une faction gagne du pouvoir) ? => Oui.
- Quelle part d'événements mortels ? La mort peut-elle venir d'un événement sans combat ? => Oui, mais la mort doit toujours venir d'un évènement qui aurait pu être évité (ne pas aller visiter le volcan pendant une éruption), ou de quelque chose dans un évènement qui aurait pu éviter (ne pas insulter le chef de la garde)

### 5. Les étapes de la vie

- Des événements propres à chaque âge (jeunesse, âge adulte, vieillesse) ? => eventuellement oui
- Des événements de saison, de météo, de fête (calendrier) ? => oui
- Des événements liés à l'espèce, la classe, le passé, la réputation, les traits ? => Oui, on pourrait même imaginer parfois ne pas commencer en ville etc, mais plutôt à un endroit raccord avec le passé, ou rarement commencer directement dans une suite d'évènements (à la façon dont on commence BG3 dans un vaisseau de flagelleurs)

### 6. Les nouveaux lieux

Quels pools ajouter en priorité ? Pistes : taverne, mine, route, rivière, montagne, ruines, temple, marché, port,
autre ville. Chacun a-t-il ses PNJ, ses boutiques, son terrain de combat ? => Chacun aura ça oui, pas de priorités d'un sur l'autre à mon sens actuellement.

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
