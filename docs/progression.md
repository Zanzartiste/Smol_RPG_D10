# Progression — Lifantasy

> Document de conception : comment le personnage gagne de l'expérience et progresse au cours d'une vie. Les classes
> ([classes.md](classes.md)), les dons ([dons.md](dons.md)) et les compétences ([competences.md](competences.md))
> décrivent ce qu'on gagne ; cette fiche décide **comment et à quel rythme**. La progression d'une vie à l'autre
> (Creator Points, héritage) est remise à plus tard.

## Ce qui existe

- **Niveaux 1 à 20**, avec la table d'XP de D&D pour l'instant (300 XP pour le niveau 2, 355 000 pour le niveau 20).
- **Sources d'XP** : les créatures vaincues en combat (une créature enfuie ne rapporte rien) et les effets
  d'événements (`xp`).
- **Gains par niveau** (tableur des classes) : un rang de compétence tous les deux niveaux, la sous-classe au niveau 3,
  des aptitudes de sous-classe aux niveaux 6, 9, 12 et 16, un attribut aux niveaux 5, 10, 15 et 20 ; des dons de
  niveau à placer.
- **Pas de PV par niveau** pour l'instant : la fragilité est voulue.
- **Vieillissement** : les attributs changent avec l'âge (règles par étape de vie).
- Multiclassage libre : on choisit la classe qui progresse à chaque niveau.

## Questions à trancher

### 1. D'où vient l'expérience ?

L'XP de combat pousse à se battre ; dans un jeu de vies, d'autres chemins devraient compter. Lesquelles garder ?

- Combats (actuel).
- Événements réussis (actuel, au cas par cas).
- Quêtes et demandes de PNJ terminées.
- Découvertes : un nouveau lieu, un fait révélé, un secret.
- Métiers : forger une pièce de maître, une première vente, une recette inventée.
- Social : se marier, élever un enfant, devenir chef de faction.
- Le simple temps qui passe (expérience de la vie : un peu d'XP par an).

### 2. Une seule XP ou plusieurs ?

- **A. Une seule XP** qui fait monter le niveau (actuel).=> On reste sur ce système.
- **B. Progression par l'usage** : les compétences montent quand on les utilise (forger fait monter l'Artisanat) ;
  le niveau ne donne que les aptitudes de classe.
- **C. Mixte** : l'XP donne les niveaux, et l'usage donne de temps en temps un rang gratuit dans la compétence
  utilisée (« vous avez appris à force de forger »).

### 3. Quel rythme dans une vie ?

- Une vie dure des dizaines d'années de jeu. À quel âge un aventurier typique doit-il atteindre le niveau 5 ? 10 ?
  Le niveau 20 doit-il être réservé à une vie exceptionnelle ? Oui clairement le niveau 20 doit être particulièrement difficile à atteindre.
- Faut-il garder la table de D&D ou en faire une plus plate (les premiers niveaux vite, les suivants très lents) ?
- La vieillesse doit-elle freiner la progression (moins d'XP après un certain âge) ? => non pas spécialement.

### 4. Quand applique-t-on un niveau ?

- Tout de suite (actuel : les choix s'ouvrent au hub) ? => en cliquant sur un bouton level up dans la fiche de personnage, qui doit "briller" (tout comme son onglet) quand le niveau peut être monté.
- Seulement en se reposant ou en s'entraînant (auprès d'un maître, pour certaines aptitudes) ? => non

### 5. Dons de niveau

- À quels niveaux ? (Ex. 4, 8, 12, 16, 19 comme D&D, ou tous les 3 niveaux.) => Pour l'instant go dire que l'on fait tous les 4 niveaux à partir du lvl 4.
- Peut-on gagner des dons hors niveau (événements, maîtres, exploits) ? => en règle générale non.

### 6. Perdre de la progression ?

- Une blessure grave, une malédiction, la vieillesse peuvent-elles faire perdre des rangs ou des attributs ? => Non mais il y aura des "handicaps" possiblement reçus avec des évènements.
- Une compétence non pratiquée pendant des années se rouille-t-elle ? => non

## Pistes (non obligatoires)

- **Entraînement** : une activité (seul ou avec un PNJ) qui donne un peu d'XP ou de rangs, contre du temps et de l'or. => Pas fan.
- **Maîtres** : certains rangs élevés (5+) ou aptitudes ne s'apprennent qu'auprès d'un maître. => Non pas nécesssaire.
- **Exploits** : des succès en jeu (vaincre l'Alpha, forger une arme +3) donnent un titre et un petit bonus. => Le titre / achievments je suis plutôt pour, pas forcément l'idée du bonus, à définir.

## Décisions (2026-10-16, reprises de questions_suite.md)

- Gains distincts, qui s'ajoutent : un rang de compétence aux niveaux pairs, un palier de sous-classe tous les
  3 niveaux (3, 6, 9… 18), +1 attribut tous les 5 niveaux (5, 10, 15, 20), un don tous les 4 niveaux (4, 8… 20)
  (fait, avec le bouton « Monter de niveau »).
- Table d'XP : celle de D&D pour l'instant ; le niveau 20 doit rester très difficile (par l'XP).
- Titres et succès : pas prioritaire.
