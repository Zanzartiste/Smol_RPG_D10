# Catalogue de l'équipement — Lifantasy

> Document de conception : il recense les **armes, armures, boucliers et accessoires** (tout ce qui se porte) qui
> doivent exister dans le jeu, avant leur saisie dans `claude_rpg/data/equipment.json`. Les objets qui restent dans le
> sac (potions, matériaux, trésors) sont dans [objets.md](objets.md). Champs techniques :
> [modele_donnees.md](modele_donnees.md), rubriques Équipement et Économie.

## Règles générales

- **Emplacements** : main principale, main secondaire, couvre-chef, torse (armure, avec bras et épaules), gants,
  jambes, chaussures, collier (1), anneaux (2).
- **Armes** : la FOR sert à l'attaque et aux dégâts ; une arme de finesse prend le meilleur de FOR et DEX, une arme
  à distance la DEX. Une arme polyvalente fait plus de dégâts à deux mains (sans bouclier). Une arme à deux mains et
  un bouclier s'excluent.
- **Armures** : CA de base + DEX (vêtement et légère), + DEX plafonnée à 2 (intermédiaire), sans DEX (lourde).
  Toute armure peut être portée, mais sous la **Force conseillée** (vêtement 0, légère 10, intermédiaire 12,
  lourde 14) le personnage est **encombré**.
- **Encombrement** : un malus à **tous les jets de FOR et de DEX** (attaques, sauvegardes, tests, initiative, fuite),
  qui dépend de l'importance de l'encombrement :
  - armure trop lourde : −1 par tranche de 2 points de Force manquants ;
  - charge : chaque objet a un **poids** (kg). Le groupe peut porter 7,5 kg par point de Force de chaque membre
    (sac partagé + objets portés) ; au-delà, −1 par tranche de 10 % de surcharge ;
  - les deux se cumulent, avec un maximum de −5 (réglages : `rules.json › encumbrance`).
- **Plusieurs types de dégâts** : une arme peut ajouter des dégâts d'un autre type (Langue de feu : tranchant + feu).
- **Prix** : environ un cinquième des prix du SRD, pour que la potion de soins coûte 10 po. **Tout marchand rachète
  tout** (sauf les objets de quête), à 50 % de la valeur. La Persuasion du meilleur négociateur du groupe ajuste les
  prix d'achat **et** de revente (jusqu'à ±15 %).
- **Forge** :
  - **Amélioration** d'une arme, d'une armure (pas d'un vêtement) ou d'un bouclier ordinaire : +1 (50 po), +2 (150 po),
    +3 (400 po). +N au toucher et aux dégâts pour une arme, +N à la CA sinon. Les objets déjà magiques ne
    s'améliorent pas.
  - **Fabrication** à partir de matériaux (voir Recettes ci-dessous).
- ⚠️ Licence : les armes, armures et objets magiques du SRD 5.1 sont réutilisables (CC-BY 4.0).

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Catégorie** : arme / armure (torse) / bouclier / accessoire (couvre-chef, gants, jambes, chaussures, collier, anneau).
- **Dégâts** (arme) : ex. 1d8 tranchant (+ 1d6 feu).
- **Propriétés** (arme) : finesse, légère, lancer, polyvalente (1d10), lourde, à deux mains, à distance.
- **Type et CA** (armure) : vêtement / légère / intermédiaire / lourde, CA de base.
- **Force conseillée** (armure) : si différente de celle du type.
- **Effets** : bonus, résistances… (objets magiques).
- **Poids** : en kg.
- **Rareté** : commun / peu commun / rare / très rare / légendaire.
- **Valeur** : en po.
- **Où le trouver** : boutique, forge, butin, événement, quête…
- **Description** : une phrase d'ambiance.
```

---

## Armes

### Mains nues (`unarmed`)

- **Dégâts** : 1 contondant.
- **Propriétés** : aucune.

### Gourdin (`club`)

- **Dégâts** : 1d4 contondant.
- **Propriétés** : légère.
- **Poids** : 1 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Dague (`dagger`)

- **Dégâts** : 1d4 perforant.
- **Propriétés** : finesse, légère, lancer.
- **Poids** : 0.5 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (30 %).

### Bâton (`quarterstaff`)

- **Dégâts** : 1d6 contondant.
- **Propriétés** : polyvalente (1d8).
- **Poids** : 2 kg.
- **Valeur** : 1 po.
- **Où le trouver** : départ : Magicien.

### Masse d'armes (`mace`)

- **Dégâts** : 1d6 contondant.
- **Propriétés** : aucune.
- **Poids** : 2 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Hachette (`handaxe`)

- **Dégâts** : 1d6 tranchant.
- **Propriétés** : légère, lancer.
- **Poids** : 1 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge).

### Épée courte (`shortsword`)

- **Dégâts** : 1d6 perforant.
- **Propriétés** : finesse, légère.
- **Poids** : 1 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (15 %).

### Cimeterre (`scimitar`)

- **Dégâts** : 1d6 tranchant.
- **Propriétés** : finesse, légère.
- **Poids** : 1.5 kg.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Rapière (`rapier`)

- **Dégâts** : 1d8 perforant.
- **Propriétés** : finesse.
- **Poids** : 1 kg.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Roublard.

### Épée longue (`longsword`)

- **Dégâts** : 1d8 tranchant.
- **Propriétés** : polyvalente (1d10).
- **Poids** : 1.5 kg.
- **Valeur** : 3 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), départ : Guerrier.

### Hache à deux mains (`greataxe`)

- **Dégâts** : 1d12 tranchant.
- **Propriétés** : lourde, à deux mains.
- **Poids** : 3.5 kg.
- **Valeur** : 6 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, butin : Colosse tatoué (25 %).

### Arc court (`shortbow`)

- **Dégâts** : 1d6 perforant.
- **Propriétés** : à distance, à deux mains.
- **Poids** : 1 kg.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arc long (`longbow`)

- **Dégâts** : 1d8 perforant.
- **Propriétés** : à distance, lourde, à deux mains.
- **Poids** : 1 kg.
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Armures et vêtements

### Vêtements ordinaires (`clothes`)

- **Type** : vêtement.
- **CA** : 10 + DEX.
- **Force conseillée** : aucune.
- **Poids** : 1.5 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Robe d'érudit (`robe`)

- **Type** : vêtement.
- **CA** : 10 + DEX.
- **Force conseillée** : aucune.
- **Poids** : 2 kg.
- **Valeur** : 2 po.
- **Où le trouver** : départ : Magicien.

### Armure matelassée (`padded`)

- **Type** : légère.
- **CA** : 11 + DEX.
- **Force conseillée** : 10.
- **Poids** : 4 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Armure de cuir (`leather`)

- **Type** : légère.
- **CA** : 11 + DEX.
- **Force conseillée** : 10.
- **Poids** : 5 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Roublard.

### Cuir clouté (`studded_leather`)

- **Type** : légère.
- **CA** : 12 + DEX.
- **Force conseillée** : 10.
- **Poids** : 6.5 kg.
- **Valeur** : 9 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (10 %).

### Armure de peau (`hide`)

- **Type** : intermédiaire.
- **CA** : 12 + DEX (max 2).
- **Force conseillée** : 12.
- **Poids** : 6 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Chemise de mailles (`chain_shirt`)

- **Type** : intermédiaire.
- **CA** : 13 + DEX (max 2).
- **Force conseillée** : 12.
- **Poids** : 10 kg.
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge).

### Cuirasse (`breastplate`)

- **Type** : intermédiaire.
- **CA** : 14 + DEX (max 2).
- **Force conseillée** : 12.
- **Poids** : 10 kg.
- **Valeur** : 80 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Cotte de mailles (`chain_mail`)

- **Type** : lourde.
- **CA** : 16.
- **Force conseillée** : 14.
- **Poids** : 27 kg.
- **Valeur** : 15 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Guerrier.

### Harnois (`plate`)

- **Type** : lourde.
- **CA** : 18.
- **Force conseillée** : 14.
- **Poids** : 32 kg.
- **Valeur** : 300 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Boucliers

### Bouclier (`shield`)

- **CA** : +2.
- **Poids** : 3 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Objets magiques

### Épée longue +1 (`longsword_plus_1`)

- **Dégâts** : 1d8 tranchant.
- **Propriétés** : polyvalente (1d10).
- **Effets** : +1 au toucher, +1 aux dégâts.
- **Poids** : 1.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 120 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Sa lame ne s'émousse jamais et vibre légèrement au toucher.

### Langue de feu (`flame_tongue`)

- **Dégâts** : 1d8 tranchant + 2d6 feu.
- **Propriétés** : polyvalente (1d10).
- **Poids** : 1.5 kg.
- **Rareté** : rare.
- **Valeur** : 400 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Une épée longue dont la lame s'embrase au moindre mouvement.

### Dague +1 (`dagger_plus_1`)

- **Dégâts** : 1d4 perforant.
- **Propriétés** : finesse, légère, lancer.
- **Effets** : +1 au toucher, +1 aux dégâts.
- **Poids** : 0.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 80 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Une lame fine, gravée de runes de précision.

### Cuir clouté +1 (`studded_leather_plus_1`)

- **Type** : légère.
- **CA** : 12 + DEX.
- **Force conseillée** : 10.
- **Effets** : +1 CA.
- **Poids** : 6.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 120 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Un cuir enchanté, souple comme une seconde peau.

### Anneau de protection (`ring_of_protection`)

- **Emplacement** : anneau.
- **Effets** : +1 CA, +1 aux jets de sauvegarde.
- **Poids** : 0 kg.
- **Rareté** : peu commun.
- **Valeur** : 150 po.
- **Où le trouver** : butin : Alpha des loups (100 %).
- **Description** : Un anneau d'argent qui détourne les coups et les sortilèges.

### Anneau de résistance au feu (`ring_fire_resistance`)

- **Emplacement** : anneau.
- **Effets** : résistance au feu.
- **Poids** : 0 kg.
- **Rareté** : rare.
- **Valeur** : 200 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Un anneau de cuivre toujours tiède.

### Amulette de vigueur (`amulet_vigor`)

- **Emplacement** : collier.
- **Effets** : +1 PV par niveau.
- **Poids** : 0.2 kg.
- **Rareté** : peu commun.
- **Valeur** : 100 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Un pendentif de chêne qui bat comme un cœur.

### Gantelets de puissance d'ogre (`gauntlets_ogre_power`)

- **Emplacement** : gants.
- **Effets** : +2 FOR.
- **Poids** : 1 kg.
- **Rareté** : rare.
- **Valeur** : 300 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : De lourds gantelets cloutés qui décuplent la poigne.

### Bottes elfiques (`elven_boots`)

- **Emplacement** : chaussures.
- **Effets** : maîtrise de Discrétion.
- **Poids** : 0.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 100 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Des bottes souples dont les pas ne font aucun bruit.

---

## Recettes de la forge

- **Dague** : Minerai de fer ×1.
- **Hachette** : Minerai de fer ×1.
- **Épée courte** : Minerai de fer ×1, 1 po.
- **Épée longue** : Minerai de fer ×2, 1 po.
- **Chemise de mailles** : Minerai de fer ×5, 3 po.
- **Cuir clouté** : Peau de loup ×2, Minerai de fer ×1, 1 po.

---

## Équipement candidat (à compléter)

### Armes du SRD manquantes

- Lance, javeline, fronde, arbalètes (légère, lourde, de poing), fléau, morgenstern, marteau de guerre, pic de
  guerre, hallebarde, glaive, coutille, épée à deux mains, maillet d'armes, trident, fouet, filet, sarbacane.

### Armures du SRD manquantes

- Broigne, clibanion, crevice / harnois de plates partiel (demi-plate), armure à bandes.

### Accessoires

- Casques, chapeaux, capuches ; gants et gantelets ; jambières ; bottes ; colliers et amulettes ; anneaux.

### Objets magiques du SRD à envisager

- Cape elfique (quel emplacement ?), sac sans fond (capacité de charge), baguette de projectiles magiques, bâton de
  feu, amulette de santé, heaume de télépathie…

---

## Décisions (2026-10-13)

- Emplacements : couvre-chef, torse, gants, jambes, chaussures, collier (1), anneaux (2). La cape a disparu ; la Cape
  de protection est devenue l'Anneau de protection.
- Pas de règle spéciale pour les armes à distance pour l'instant.
- Ni munitions ni usure.
- Pas de limite au nombre d'objets magiques portés.
- Améliorations élémentaires à la forge : plus tard.

## Questions ouvertes

1. **Capes** : elles reviennent comme couche par-dessus le torse, ou elles restent absentes ?
2. **Colliers et anneaux** : on garde 1 collier et 2 anneaux, ou on autorise davantage ?
