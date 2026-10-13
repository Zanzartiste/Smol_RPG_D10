# Altérations d'état — Lifantasy

> Document de conception : c'est ici qu'on décide des états (poison, étourdi…) avant de les saisir dans
> `claude_rpg/data/status_effects.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md)
> (rubrique États).

## Règles actuelles

- Les états n'existent **qu'en combat** : ils disparaissent à la fin de la bataille.
- Ils se **cumulent en charges** : 3 charges de Poison font plus mal qu'une seule, et chaque tour en retire
  (généralement une).
- Un état est **négatif** ou **positif**. L'Antidote retire le Poison, et un effet peut retirer tous les états
  négatifs.
- On peut y être **immunisé** (ex. les elfes contre Endormi).
- Les mécaniques possibles, à combiner :
  - dégâts au début du tour (fixes par charge, ou en % des PV max) ;
  - passer son tour ;
  - dégâts infligés modifiés ;
  - absorption des dégâts reçus ;
  - **avantage ou désavantage** : à ses attaques, pour qui l'attaque, à ses sauvegardes ou à ses tests ;
  - coups critiques automatiques, sauvegardes ratées d'office, fuite impossible, aucune action hostile ;
  - disparaître si l'on subit des dégâts ;
  - perte de charges au début ou à la fin du tour.
- **Avantage / désavantage** : on lance deux d20 et on garde le meilleur (ou le pire) ; les deux s'annulent. Le dé
  écarté apparaît grisé sur le plateau.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Négatif** : oui / non.
- **Effet** : ce qu'il fait, en une ou deux phrases.
- **Charges** : ce que représente une charge, combien on en perd par tour, et quand (début / fin du tour).
- **Fin** : quand il disparaît (charges à 0, dégâts reçus, fin du combat, repos, remède…).
- **Sources** : actions, sorts, créatures, objets, événements.
- **Remèdes / immunités** : …
- **Hors combat** : non / oui (ex. une maladie qui dure des jours).
- **Couleur** : pour la pastille au-dessus du combattant.
- **Notes** : …
```

---

## États implémentés

Tous les états ci-dessous ont une mécanique en combat.

### Poison (`poisoned`)

- **Négatif** : oui.
- **Effet** : Au début de son tour, subit 1 dégât de poison par charge, puis perd 1 charge.
- **Mécanique** : 1 dégât(s) par charge au début du tour ; perd 1 charge(s) au début de son tour.
- **Sources** : Lame empoisonnée (Roublard), brigand, rat géant. Remède : Antidote.
- **Couleur** : `#7ac943`.

### Brûlure (`burning`)

- **Négatif** : oui.
- **Effet** : Au début de son tour, subit 5 % de ses PV max par charge (au moins 1 par charge, dégâts de feu), puis perd 1 charge.
- **Mécanique** : 5 % des PV max par charge au début du tour ; perd 1 charge(s) au début de son tour.
- **Sources** : Mains brûlantes (si la sauvegarde est ratée) ; tout dégât de feu (25 %).
- **Couleur** : `#f08a2e`.

### Étourdi (`stunned`)

- **Négatif** : oui.
- **Effet** : Passe son tour, puis perd 1 charge.
- **Mécanique** : passe son tour ; perd 1 charge(s) au début de son tour.
- **Sources** : Coup de pommeau (Guerrier), loup, Colosse tatoué.
- **Couleur** : `#e8d44a`.

### Affaibli (`weakened`)

- **Négatif** : oui.
- **Effet** : Inflige 1 dégât de moins par charge. Perd 1 charge à la fin de son tour.
- **Mécanique** : -1 dégât(s) infligé(s) par charge ; perd 1 charge(s) à la fin de son tour.
- **Sources** : Rayon de givre, Alpha des loups, familier.
- **Couleur** : `#9a8cc8`.

### Protection (`shielded`)

- **Négatif** : non.
- **Effet** : Chaque charge absorbe 1 point de dégâts. Disparaît au début de son prochain tour.
- **Mécanique** : chaque charge absorbe 1 point de dégâts ; perd toutes ses charges au début de son tour.
- **Sources** : Posture défensive (Guerrier), sort Bouclier.
- **Couleur** : `#8fc3e8`.

### Endormi (`asleep`)

- **Négatif** : oui.
- **Effet** : Passe ses tours (1 charge par tour) et se réveille s'il subit des dégâts. Les attaques contre lui ont l'avantage et sont des critiques si elles touchent.
- **Mécanique** : passe son tour ; avantage pour qui l'attaque ; un coup qui le touche est critique ; disparaît s'il subit des dégâts ; perd 1 charge(s) au début de son tour.
- **Sources** : sort Sommeil (Magicien, sauvegarde de SAG). Immunité : elfes.
- **Couleur** : `#6a7ac8`.

### Aveuglé (`blinded`)

- **Négatif** : oui.
- **Effet** : Désavantage à ses attaques ; avantage pour ceux qui l'attaquent. Perd 1 charge par tour.
- **Mécanique** : désavantage à ses attaques ; avantage pour qui l'attaque ; perd 1 charge(s) au début de son tour.
- **Sources** : aucune pour l'instant.
- **Couleur** : `#4a4a4a`.

### Charmé (`charmed`)

- **Négatif** : oui.
- **Effet** : Ne peut rien entreprendre contre ses ennemis (attaques, sorts offensifs). Perd 1 charge par tour.
- **Mécanique** : aucune action contre ses ennemis ; perd 1 charge(s) au début de son tour.
- **Sources** : aucune pour l'instant.
- **Couleur** : `#e070c0`.

### Effrayé (`frightened`)

- **Négatif** : oui.
- **Effet** : Désavantage à ses attaques et à ses tests (fuite comprise). Perd 1 charge par tour.
- **Mécanique** : désavantage à ses attaques ; désavantage à ses tests (fuite) ; perd 1 charge(s) au début de son tour.
- **Sources** : aucune pour l'instant.
- **Couleur** : `#a0a0d0`.

### Paralysé (`paralyzed`)

- **Négatif** : oui.
- **Effet** : Passe son tour et rate ses sauvegardes de FOR et de DEX ; les attaques contre lui ont l'avantage et sont des critiques si elles touchent. Perd 1 charge par tour.
- **Mécanique** : passe son tour ; avantage pour qui l'attaque ; un coup qui le touche est critique ; rate ses sauvegardes de Force, Dextérité ; perd 1 charge(s) au début de son tour.
- **Sources** : aucune pour l'instant.
- **Couleur** : `#c8c060`.

### À terre (`prone`)

- **Négatif** : oui.
- **Effet** : Les attaques contre lui ont l'avantage. Il se relève au début de son tour.
- **Mécanique** : avantage pour qui l'attaque ; perd toutes ses charges au début de son tour.
- **Sources** : aucune pour l'instant.
- **Couleur** : `#8a6a4a`.

### Entravé (`restrained`)

- **Négatif** : oui.
- **Effet** : Désavantage à ses attaques et à ses sauvegardes de DEX ; avantage pour ceux qui l'attaquent ; ne peut pas fuir. Perd 1 charge par tour.
- **Mécanique** : désavantage à ses attaques ; avantage pour qui l'attaque ; ne peut pas fuir ; désavantage aux sauvegardes de Dextérité ; perd 1 charge(s) au début de son tour.
- **Sources** : Empoignade (don Lutteur).
- **Couleur** : `#7a5a3a`.

### Invisible (`invisible`)

- **Négatif** : non.
- **Effet** : Avantage à ses attaques ; désavantage pour ceux qui l'attaquent. Perd 1 charge par tour.
- **Mécanique** : avantage à ses attaques ; désavantage pour qui l'attaque ; perd 1 charge(s) au début de son tour.
- **Sources** : aucune pour l'instant.
- **Couleur** : `#c8e8f0`.

---

## États candidats (à compléter)

### États du SRD pas encore déclarés

- **Assourdi** (`deafened`) : rate ce qui demande d'entendre.
- **Agrippé** (`grappled`) : ne peut pas fuir.
- **Neutralisé** (`incapacitated`) : ne peut pas agir (base de Paralysé, Étourdi…).
- **Pétrifié** (`petrified`) : changé en pierre, résistance à tous les dégâts.
- **Inconscient** (`unconscious`) : à 0 PV sans être mort, si on ajoute les jets contre la mort.
- **Épuisement** (`exhaustion`) : six niveaux cumulables (un bon candidat pour la fatigue des voyages).

### Idées propres au jeu

- **Saignement** : dégâts par charge, aggravé si la cible agit.
- **Régénération** : soigne X PV par charge au début du tour (positif).
- **Hâte / Ralenti** : une action de plus ou de moins par tour.
- **Galvanisé** : bonus aux dégâts infligés (l'inverse d'Affaibli).
- **Marqué** : la cible subit plus de dégâts du prochain coup.

---

## Décisions (2026-10-13)

- **Charges partout** : chaque état utilise ses charges à sa façon (dégâts, tours passés, absorption…).
- **Avantage et désavantage** : oui (fait : attaques, sauvegardes, fuite, tests d'événement).
- **États hors combat** (maladies, malédictions, fatigue…) : oui, à terme.
- **Jet de sauvegarde** : généralement, un état infligé en permet un.

## Questions ouvertes

1. **Combien d'états** : pas encore décidé.
2. **Résistance aux états** (moitié des charges) en plus de l'immunité : pas encore décidé.
3. **Icônes** : une icône par état en plus de la couleur ?
