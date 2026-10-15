# Jets de sauvegarde — Lifantasy

> Document de réflexion : où servent les jets de sauvegarde aujourd'hui, où ils servent dans D&D, et quelles
> alternatives existent, pour décider s'ils doivent rester dans le jeu.
>
> **Mise à jour du 2026-10-13** : avec le passage aux réserves de d10 ([systeme_de_jeu.md](systeme_de_jeu.md)),
> l'**option B** est en place à titre provisoire : résister est un jet de compétence (Physique pour FOR, DEX et CON ;
> Perspicacité pour SAG ; Érudition pour INT ; Persuasion pour CHA) contre l'attribut, sans maîtrise
> de classe (décision du 2026-10-15). Contre des dégâts, chaque succès retire un point ; contre un autre effet, c'est une opposition avec
> la compétence d'incantation du lanceur. Le reste de ce document décrit l'ancien système (d20), pour mémoire.

## Principe d'origine (d20)

- Un jet de sauvegarde, c'est la **cible** qui lance le dé pour résister à un effet : d20 + modificateur de
  l'attribut + rang de sauvegarde (provisoire : 1, ou 2 si la classe le maîtrise), contre un DD fixé par la source
  (pour un sort : 8 + rang de la compétence d'incantation + attribut d'incantation).
- C'est l'inverse d'une attaque, où c'est l'**attaquant** qui lance le dé contre la CA de la cible.

---

## Où le jeu les utilise aujourd'hui

### Sorts et actions

- **Mains brûlantes** et **Boule de feu** : sauvegarde de DEX, moitié des dégâts si elle est réussie (et pas de
  Brûlure).
- **Sommeil** : sauvegarde de SAG, sinon la cible s'endort.
- **Intimider** (action commune) : Persuasion (FOR) de l'acteur contre une sauvegarde de SAG de la cible.

### Aptitudes, dons, objets

- **Dérobade** (Roublard 7) : sauvegarde de DEX pour moitié → rien si réussie, moitié si ratée.
- **Inflexible** (Guerrier 9) : relance une sauvegarde ratée.
- **Résistant** (don) : +1 rang de sauvegarde dans un attribut.
- **Cape de protection**, **Anneau de protection** : +1 à toutes les sauvegardes.
- Modificateur `save_advantage` : avantage aux sauvegardes d'un attribut (aucune source pour l'instant).

### États

- **Paralysé** : rate d'office ses sauvegardes de FOR et de DEX.
- **Entravé** : désavantage aux sauvegardes de DEX.

### Événements

- Le format existe (`{"save": "con", "dc": 12}`), mais **aucun événement ne l'utilise** pour l'instant.

### Créatures

- Bonus de sauvegarde (`saves`) et DD de leurs effets (`save_dc`) : aucune créature ne s'en sert encore.

---

## Où D&D les utilise (pour comparer)

- **DEX** : esquiver une explosion, un souffle de dragon, un piège, un éboulement.
- **CON** : résister au poison, à une maladie, à l'épuisement, garder sa concentration sur un sort.
- **FOR** : ne pas être renversé, repoussé, agrippé.
- **SAG** : résister au charme, à la peur, à la domination, à certaines illusions.
- **INT** : percer une illusion, résister à une attaque psychique.
- **CHA** : résister au bannissement, à la possession.

---

## Options possibles

### Option A — Garder les sauvegardes (comme aujourd'hui)

- Une sauvegarde par attribut, avec un rang qui progresse comme les compétences.
- **Pour** : fidèle à D&D ; les sorts de zone, poisons et pièges ont un fonctionnement clair.
- **Contre** : une règle de plus à expliquer ; six valeurs à afficher sur la fiche.

### Option B — Les remplacer par des compétences

- Résister se fait avec une compétence existante : Physique (FOR, DEX, CON) pour les effets physiques,
  Perspicacité (SAG) ou une nouvelle compétence « Volonté » pour les effets mentaux.
- **Pour** : un seul système (les rangs) ; cohérent avec la refonte des compétences ; l'Esquive des réactions
  utilise déjà Physique (DEX).
- **Contre** : Physique devient très importante ; il faut décider quelle compétence pour chaque effet.

### Option C — Des défenses fixes (comme D&D 4e)

- Trois défenses fixes, comme la CA : **Réflexes** (DEX), **Vigueur** (CON/FOR), **Volonté** (SAG/CHA) = 10 +
  attribut + rang. C'est **l'attaquant** qui lance le dé contre la défense.
- **Pour** : toujours l'attaquant qui lance (plus rapide, plus lisible) ; même logique que les attaques.
- **Contre** : on perd le suspense de « vais-je résister ? » côté joueur.

### Option D — Tout passer par les réactions

- Les effets de zone se résolvent comme des attaques : la cible peut esquiver (réaction, Physique DEX) si elle a
  gardé une action ; les effets mentaux se résistent avec une réaction « Volonté ».
- **Pour** : renforce le système de réactions déjà en place.
- **Contre** : un personnage sans réaction ne résiste à rien ; à équilibrer.

---

## Questions

1. Quelle option (ou quel mélange) te parle le plus ?
2. Les effets mentaux (charme, peur, sommeil) méritent-ils une compétence dédiée (« Volonté »), ou Perspicacité
   suffit ?
3. Les poisons et maladies hors combat (temps long) : résistance par CON (sauvegarde), par Physique, ou autre ?
