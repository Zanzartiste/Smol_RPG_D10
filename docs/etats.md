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
  - perte de charges au début ou à la fin du tour.

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

## États implémentés (avec une mécanique)

### Poison (`poisoned`)

- **Négatif** : oui.
- **Effet** : au début de son tour, subit 1 dégât **brut** par charge (qui ignore résistances et Protection).
- **Charges** : −1 au début de chaque tour.
- **Fin** : charges à 0, ou Antidote.
- **Sources** : Lame empoisonnée (Roublard, 3 charges), brigand, rat géant.
- **Remèdes / immunités** : Antidote ; don Résistant.
- **Couleur** : vert.

### Brûlure (`burning`)

- **Négatif** : oui.
- **Effet** : au début de son tour, subit 5 % de ses PV max par charge (au moins 1 par charge), en dégâts de feu.
- **Charges** : −1 au début de chaque tour.
- **Sources** : Mains brûlantes (1 charge, si la cible rate sa sauvegarde).
- **Remèdes / immunités** : résistance ou immunité au feu (elles réduisent les dégâts).
- **Couleur** : orange.

### Étourdi (`stunned`)

- **Négatif** : oui.
- **Effet** : passe son tour.
- **Charges** : −1 au début de chaque tour (une charge = un tour perdu).
- **Sources** : Coup de pommeau (Guerrier), morsure du loup, Colosse tatoué.
- **Couleur** : jaune.

### Affaibli (`weakened`)

- **Négatif** : oui.
- **Effet** : inflige 1 dégât de moins par charge.
- **Charges** : −1 à la **fin** de chaque tour.
- **Sources** : Rayon de givre (2 charges), Alpha des loups, familier.
- **Couleur** : violet.

### Protection (`shielded`)

- **Négatif** : non.
- **Effet** : chaque charge absorbe 1 point de dégâts (et disparaît en l'absorbant).
- **Fin** : toutes les charges disparaissent au début de son prochain tour.
- **Sources** : Posture défensive (Guerrier, 5 charges), sort Bouclier (6 charges).
- **Couleur** : bleu clair.

---

## États déclarés, sans mécanique pour l'instant

Ils existent dans les données (pour les immunités notamment) mais ne font encore rien. La plupart demandent
l'**avantage et le désavantage** (lancer deux d20 et garder le meilleur ou le pire), qui n'existent pas encore en combat.

### Endormi (`asleep`)

- **Effet prévu** : inconscient (passe ses tours) jusqu'à ce qu'il subisse des dégâts ou qu'un allié le réveille.
- **Immunités** : les elfes.

### Aveuglé (`blinded`)

- **Effet prévu (SRD)** : désavantage à ses attaques, avantage pour ceux qui l'attaquent.

### Charmé (`charmed`)

- **Effet prévu (SRD)** : ne peut pas attaquer celui qui l'a charmé.

### Effrayé (`frightened`)

- **Effet prévu (SRD)** : désavantage à ses attaques et à ses tests tant que la source de sa peur est là.

### Paralysé (`paralyzed`)

- **Effet prévu (SRD)** : ne peut pas agir, rate ses sauvegardes de FOR et DEX, et les attaques qui le touchent sont
  des critiques.

### À terre (`prone`)

- **Effet prévu (SRD)** : désavantage à ses attaques. Sans positionnement, il faudra trancher : avantage pour tous
  ceux qui l'attaquent ?

---

## États candidats (à compléter)

### États du SRD pas encore déclarés

- **Assourdi** (`deafened`) : rate ce qui demande d'entendre.
- **Agrippé** (`grappled`) : ne peut pas fuir.
- **Neutralisé** (`incapacitated`) : ne peut pas agir (base de Paralysé, Étourdi…).
- **Invisible** (`invisible`) : avantage à ses attaques, désavantage pour l'attaquer.
- **Pétrifié** (`petrified`) : changé en pierre, résistance à tous les dégâts.
- **Entravé** (`restrained`) : désavantage aux attaques et sauvegardes de DEX.
- **Inconscient** (`unconscious`) : à 0 PV sans être mort, si on ajoute les jets contre la mort.
- **Épuisement** (`exhaustion`) : six niveaux cumulables (un bon candidat pour la fatigue des voyages).

### Idées propres au jeu

- **Saignement** : dégâts par charge, aggravé si la cible agit.
- **Régénération** : soigne X PV par charge au début du tour (positif).
- **Hâte / Ralenti** : une action de plus ou de moins par tour.
- **Galvanisé** : bonus aux dégâts infligés (l'inverse d'Affaibli).
- **Marqué** : la cible subit plus de dégâts du prochain coup.

---

## Questions ouvertes

1. **Charges ou durée** : on garde le système de charges (à la PokeRogue / Slay the Spire) pour tous les états, ou
   certains états D&D gardent une durée en rounds avec un jet de sauvegarde à chaque tour pour s'en débarrasser ?
2. **Avantage / désavantage** : faut-il l'ajouter au combat ? C'est nécessaire pour la plupart des états du SRD
   (Aveuglé, À terre, Entravé, Invisible…).
3. **États hors combat** : maladies, malédictions, fatigue, ivresse, blessures graves… qui durent des jours et se
   soignent par des événements, du repos ou un guérisseur ? Ils rejoindraient le temps long (voyages, années).
4. **Combien d'états** : une petite liste lisible (une dizaine), ou toute la liste du SRD plus les idées propres au jeu ?
5. **Résistances aux états** : uniquement des immunités (tout ou rien), ou aussi une résistance (moitié des charges) ?
6. **Jets de sauvegarde** : un état infligé doit-il toujours permettre une sauvegarde (comme dans D&D), ou seulement
   certains ? Aujourd'hui, seul le Brûlure de Mains brûlantes en dépend.
7. **Lien avec les types de dégâts** : voir la question 6 de [types_de_degats.md](types_de_degats.md).
8. **Icônes** : une icône par état en plus de la couleur ?
