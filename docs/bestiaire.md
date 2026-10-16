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
  table de créatures du lieu. => Plutôt comme ça oui, mais avec un budget en fonction de la difficulté de la région/zone...
- **C. Le monde ne s'adapte pas** : la forêt est dangereuse quoi qu'il arrive ; c'est au joueur de savoir où il va
  (plus roguelite, plus mortel). Des indices (rumeurs, Perception) préviennent du danger. => En macro on se rapproche de ça

### 2. Les créatures progressent-elles ?

- Variantes de rang (louveteau, loup, alpha, loup ancien) écrites à la main ? 
- Ou un modificateur générique (« vétéran », « d'élite » : +1 à tous les attributs, +1 dé) ?
- Le monde se durcit-il avec les années (les bandits s'organisent, une bête légendaire apparaît) ?

=> Le monde peut autant se durcir que s'adoucir que changer avec le temps (un nécromancien s'installe dans la forêt, ce qui augmente la difficulté et change les monstres, si les PJ ne s'en occupe pas, peut être qu'il finira par attaquer la ville et gagner ou perdre, ce qui peut alors rendre la région plus difficile ou facile...)

### 3. Quelles familles de créatures ?

À choisir selon le lore ([monde.md](monde.md)) : bêtes, humanoïdes (brigands, soldats, cultistes), morts-vivants,
créatures féeriques, élémentaires, démons, dragons, aberrations… Lesquelles existent dans ce monde, et lesquelles
sont rares ?

- Plant & Fungi
- Amorphs / invertébrés (Slimes, Bugs, Arachnids, Worms, Crustacés, Pieuvres...)
- Poissons (Poissons, Requins, Raies...)
- Scaled (Lézards, dragons, Dinosaures, tortues...)
- Bêtes (Loups, Licornes, rongeurs, cétacés...)
- Humanoides (Elfes, Nains, Humains, Gobelins...)
- Morts-vivants tangibles & intangibles (Zombies, Fantômes...)
- Material (Golems, élémentaires, objets animés, Machines, Pièges...)
- Monstruosités (Chimères, Manticores, Sphinx...)
- Avians (Autruches, Toucan, Perruches, Phoenix...)

Pour l'instant j'aurais ça, je réfléchis encore à si je créé une catégorie pour les créatures angeliques, et une autre pour celles démoniaques, ou si je les groupe ensemble, ou si je ne les mets pas.

### 4. Ennemis et espèces jouables

- Un ennemi d'une espèce jouable (un brigand nain) est-il un PNJ du monde (avec nom, relations, souvenirs) ou une
  créature anonyme ? Plutôt une créature anonyme sauf si on décide de le capturer / l'interroguer / lui parler en combat...
- Peut-on épargner, capturer, recruter un ennemi vaincu ? => Peut être pas recruter immédiatement, mais éventuellement ce serait pas mal. Peut être même qu'on peut capturer et recruter une créature qui se fera passer pour notre allié jusqu'à pouvoir nous trahir etc
- Les ennemis qui fuient reviennent-ils (rancune, vengeance) ? => Oui ce serait pas mal, et le mieux serait qu'ils apprennent (en fonction de leur degré d'intelligence) de ce qu'ils ont subit pendant le combat fuit.

### 5. Boss et créatures uniques

- Des créatures nommées, uniques dans le monde (le Loup de Brumeval), qui se souviennent du joueur d'une vie à
  l'autre ? => Ils ne se souviendraient pas d'une vie à l'autre du joueur, sauf très très grosses exceptions.
- Des phases de combat (change de comportement à mi-PV) ? => Oui c'est préférable. J'aime aussi l'idée d'actions "légendaires" qui sont "annoncées" et auxquelles les personnages peuvent se préparer ou non.
- Un butin unique (relique qui traverse les vies) ? => non.

### 6. Butin et ressources

- Les bêtes donnent-elles des matériaux (peaux, crocs) pour l'artisanat, avec un test (Nature) pour les récupérer ? => Oui
- Les humanoïdes donnent-ils leur équipement réel (ce qu'ils portaient) ? => Oui

### 7. Connaissance des monstres

- Un test d'Érudition ou de Nature révèle-t-il les points faibles (résistances, vulnérabilités) ? => Oui ça doit pouvoir. On doit pouvoir "chercher les points faibles" en combat. Sinon c'est la valeur passive qui est utilisée.
- Un carnet de bestiaire qui se remplit, et qui traverse les vies ? => Pourquoi pas, dans le menu par exemple.

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

## Décisions (2026-10-16, reprises de questions_suite.md)

- Créatures célestes et démoniaques : aucune catégorie pour l'instant.
- Budget de rencontre par difficulté de zone : à tester.
- Chercher les points faibles : une action (deux avec Se préparer, pour +2 dés) ; Nature ou Érudition (la meilleure)
  contre une créature naturelle, sinon Érudition ; ce qu'on découvre vaut pour toute l'espèce (carnet de bestiaire
  de la vie) (fait).
- Fuite : les humanoïdes, mais aussi les bêtes sauvages, peuvent fuir. Les fuyards pourront revenir plus tard avec
  des renforts, ou prévenir leurs alliés, qui seront alors préparés à affronter le groupe (à faire).
- Budget de rencontre, pour commencer : zones ville 1, forêt proche 2, camp des brigands 3 ; une rencontre vaut au
  plus « zone × 2 » créatures de taille 0 (à faire).
- Créatures armées : elles portent armes et armures, comme les personnages (à faire).
- Chasses (menu Chercher…) : loups 2, camp des brigands 3, brigands en ville 2 (Perception) ; en ville, c'est un vrai
  combat (fait).
