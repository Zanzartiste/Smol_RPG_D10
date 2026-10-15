# Bestiaire — Lifantasy

> Document de conception : c'est ici qu'on décrit les créatures (ennemis, invocations, bêtes) avant de les saisir dans
> `claude_rpg/data/creatures.json`. Les champs techniques sont dans [modele_donnees.md](modele_donnees.md) ; les
> règles de combat dans [systeme_de_jeu.md](systeme_de_jeu.md).

## Ce qui existe

- **Créatures** : Loup, Alpha des loups, Brigand, Rebouteux des brigands, Colosse tatoué, Rat géant ; invocations :
  Familier, Loup spectral.
- Chaque créature a des attributs, des rangs de compétence, une taille (PV), des actions, un moral (elle peut fuir),
  de l'XP, du butin, une IA (chasseur, lâche, soigneur, protecteur) et une cause de mort pour la chronique.
- Les rencontres sont posées par les événements (ex. une meute de loups dans la forêt).

## Questions à trancher

### 1. Comment doser la difficulté des rencontres ?

- **A. À la main** : chaque événement cite ses créatures (actuel).
- **B. Par budget** : une rencontre a un budget selon le niveau du groupe et le lieu, rempli au hasard dans une
  table de créatures du lieu.
- **C. Le monde ne s'adapte pas** : la forêt est dangereuse quoi qu'il arrive ; c'est au joueur de savoir où il va
  (plus roguelite, plus mortel). Des indices (rumeurs, Perception) préviennent du danger.

### 2. Les créatures progressent-elles ?

- Variantes de rang (louveteau, loup, alpha, loup ancien) écrites à la main ?
- Ou un modificateur générique (« vétéran », « d'élite » : +1 à tous les attributs, +1 dé) ?
- Le monde se durcit-il avec les années (les bandits s'organisent, une bête légendaire apparaît) ?

### 3. Quelles familles de créatures ?

À choisir selon le lore ([monde.md](monde.md)) : bêtes, humanoïdes (brigands, soldats, cultistes), morts-vivants,
créatures féeriques, élémentaires, démons, dragons, aberrations… Lesquelles existent dans ce monde, et lesquelles
sont rares ?

### 4. Ennemis et espèces jouables

- Un ennemi d'une espèce jouable (un brigand nain) est-il un PNJ du monde (avec nom, relations, souvenirs) ou une
  créature anonyme ?
- Peut-on épargner, capturer, recruter un ennemi vaincu ?
- Les ennemis qui fuient reviennent-ils (rancune, vengeance) ?

### 5. Boss et créatures uniques

- Des créatures nommées, uniques dans le monde (le Loup de Brumeval), qui se souviennent du joueur d'une vie à
  l'autre ?
- Des phases de combat (change de comportement à mi-PV) ?
- Un butin unique (relique qui traverse les vies) ?

### 6. Butin et ressources

- Les bêtes donnent-elles des matériaux (peaux, crocs) pour l'artisanat, avec un test (Nature) pour les récupérer ?
- Les humanoïdes donnent-ils leur équipement réel (ce qu'ils portaient) ?

### 7. Connaissance des monstres

- Un test d'Érudition ou de Nature révèle-t-il les points faibles (résistances, vulnérabilités) ?
- Un carnet de bestiaire qui se remplit, et qui traverse les vies ?

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Famille** : bête, humanoïde, mort-vivant…
- **Où** : lieux et événements où on la rencontre.
- **Taille** : −4 à 5.
- **Attributs** : FOR, DEX, CON, INT, SAG, CHA.
- **Compétences** : Armes de mêlée 3, Physique 2…
- **Actions** : morsure (dégâts, état), cri, soin…
- **Défenses** : armure, résistances, immunités.
- **Comportement (IA)** : chasseur, lâche, soigneur, protecteur… ; moral.
- **Butin** : or, objets, matériaux.
- **XP** : …
- **Description** : une phrase d'ambiance.
```

## Catalogue

À compléter : reprendre les créatures existantes, puis ajouter les nouvelles.

## Idées de créatures

- Sanglier, ours, araignée géante, nuée de corbeaux.
- Garde corrompu, chasseur de primes, cultiste, mercenaire.
- Squelette, goule, revenant (lié aux vies précédentes ?).
- Feu follet, dryade, gobelin.
- Une bête légendaire par région.
