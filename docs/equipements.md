# Catalogue de l'équipement — Lifantasy

> Document de conception : il recense les **armes, armures, boucliers et accessoires** (tout ce qui se porte) qui
> doivent exister dans le jeu, avant leur saisie dans `claude_rpg/data/equipment.json`. Les objets qui restent dans le
> sac (potions, matériaux, trésors) sont dans [objets.md](objets.md). Champs techniques :
> [modele_donnees.md](modele_donnees.md), rubriques Équipement et Économie.

## Règles générales

- **Emplacements** : main principale, main secondaire, couvre-chef, torse (armure, avec bras et épaules), cape,
  gants, jambes, chaussures, collier (1), anneaux (2).
- **Armes** (voir [systeme_de_jeu.md](systeme_de_jeu.md)) : on attaque avec [rang de la compétence de l'arme] d10
  contre la FOR (finesse : le meilleur de FOR et DEX ; à distance : la DEX). Les **dégâts** sont autant de d10 contre
  un **seuil** propre à l'arme : celui de l'attaque + un bonus (plus l'arme est lourde, plus il est haut), ou un seuil
  fixe (arcs) ; chaque succès est un point de dégâts. Une arme polyvalente a +1 au seuil à deux mains (sans bouclier).
  Une arme à deux mains et un bouclier s'excluent.
- **Armures** : leurs points d'**Armure** baissent d'autant le seuil des dégâts subis (sans passer sous 1). Toute
  armure peut être portée, mais sous la **Force conseillée** (vêtement 0, légère 4, intermédiaire 5, lourde 6) le
  personnage est **encombré**. L'Esquive naturelle (DEX ÷ 3) ne dépend pas de l'armure.
- **Encombrement** : des **dés en moins à tous les jets de FOR et de DEX** (attaques, résistances, tests, fuite ;
  l'initiative perd autant de points) :
  - armure trop lourde : −1 dé par point de Force manquant ;
  - charge : chaque objet a un **poids** (kg). Le groupe peut porter 18 kg par point de Force de chaque membre
    (sac partagé + objets portés) ; au-delà, −1 dé par tranche de 25 % de surcharge ;
  - les deux se cumulent, avec un maximum de −3 dés (réglages : `rules.json › encumbrance`).
- **Plusieurs types de dégâts** : une arme peut ajouter des dégâts d'un autre type (Langue de feu : tranchant + feu).
- **Prix** : environ un cinquième des prix du SRD, pour que la potion de soins coûte 10 po. **Tout marchand rachète
  tout** (sauf les objets de quête), à 50 % de la valeur. La Persuasion du meilleur négociateur du groupe ajuste les
  prix d'achat **et** de revente (jusqu'à ±15 %).
- **Forge** :
  - **Amélioration** d'une arme, d'une armure (pas d'un vêtement) ou d'un bouclier ordinaire : +1 (50 po), +2 (150 po),
    +3 (400 po). +N dés au toucher et +N au seuil des dégâts pour une arme, +N Armure sinon. Les objets déjà
    magiques ne s'améliorent pas.
  - **Fabrication** à partir de matériaux (voir Recettes ci-dessous).
- ⚠️ Licence : les armes, armures et objets magiques du SRD 5.1 sont réutilisables (CC-BY 4.0).

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Catégorie** : arme / armure (torse) / bouclier / accessoire (couvre-chef, cape, gants, jambes, chaussures, collier, anneau).
- **Dégâts** (arme) : type et seuil, ex. tranchant, seuil de l'attaque +1 (+ feu 2d10 ≤ 5).
- **Propriétés** (arme) : finesse, légère, lancer, polyvalente, lourde, à deux mains, à distance.
- **Type et Armure** (armure) : vêtement / légère / intermédiaire / lourde, points d'Armure.
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

- **Dégâts** : contondant, seuil FOR -2.
- **Propriétés** : aucune.

### Gourdin (`club`)

- **Dégâts** : contondant, seuil de l'attaque -1.
- **Propriétés** : légère.
- **Poids** : 1 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Dague (`dagger`)

- **Dégâts** : perforant, seuil de l'attaque -1.
- **Propriétés** : finesse, légère, lancer.
- **Poids** : 0.5 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (30 %).

### Bâton (`quarterstaff`)

- **Dégâts** : contondant, seuil de l'attaque.
- **Propriétés** : polyvalente (+1 au seuil à deux mains).
- **Poids** : 2 kg.
- **Valeur** : 1 po.
- **Où le trouver** : départ : Magicien.

### Masse d'armes (`mace`)

- **Dégâts** : contondant, seuil de l'attaque.
- **Propriétés** : aucune.
- **Poids** : 2 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Hachette (`handaxe`)

- **Dégâts** : tranchant, seuil de l'attaque.
- **Propriétés** : légère, lancer.
- **Poids** : 1 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge).

### Épée courte (`shortsword`)

- **Dégâts** : perforant, seuil de l'attaque.
- **Propriétés** : finesse, légère.
- **Poids** : 1 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (15 %).

### Cimeterre (`scimitar`)

- **Dégâts** : tranchant, seuil de l'attaque.
- **Propriétés** : finesse, légère.
- **Poids** : 1.5 kg.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Rapière (`rapier`)

- **Dégâts** : perforant, seuil de l'attaque +1.
- **Propriétés** : finesse.
- **Poids** : 1 kg.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Roublard.

### Épée longue (`longsword`)

- **Dégâts** : tranchant, seuil de l'attaque +1.
- **Propriétés** : polyvalente (+1 au seuil à deux mains).
- **Poids** : 1.5 kg.
- **Valeur** : 3 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), départ : Guerrier.

### Hache à deux mains (`greataxe`)

- **Dégâts** : tranchant, seuil de l'attaque +3.
- **Propriétés** : lourde, à deux mains.
- **Poids** : 3.5 kg.
- **Valeur** : 6 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, butin : Colosse tatoué (25 %).

### Arc court (`shortbow`)

- **Dégâts** : perforant, seuil fixe 5.
- **Propriétés** : à distance, à deux mains.
- **Poids** : 1 kg.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arc long (`longbow`)

- **Dégâts** : perforant, seuil fixe 6.
- **Propriétés** : à distance, lourde, à deux mains.
- **Poids** : 1 kg.
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Armures et vêtements

### Vêtements ordinaires (`clothes`)

- **Type** : vêtement.
- **Armure** : 0.
- **Force conseillée** : aucune.
- **Poids** : 1.5 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Robe d'érudit (`robe`)

- **Type** : vêtement.
- **Armure** : 0.
- **Force conseillée** : aucune.
- **Poids** : 2 kg.
- **Valeur** : 2 po.
- **Où le trouver** : départ : Magicien.

### Armure matelassée (`padded`)

- **Type** : légère.
- **Armure** : 1.
- **Force conseillée** : 4.
- **Poids** : 4 kg.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Armure de cuir (`leather`)

- **Type** : légère.
- **Armure** : 1.
- **Force conseillée** : 4.
- **Poids** : 5 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Roublard.

### Cuir clouté (`studded_leather`)

- **Type** : légère.
- **Armure** : 1.
- **Force conseillée** : 4.
- **Poids** : 6.5 kg.
- **Valeur** : 9 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (10 %).

### Armure de peau (`hide`)

- **Type** : intermédiaire.
- **Armure** : 1.
- **Force conseillée** : 5.
- **Poids** : 6 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Chemise de mailles (`chain_shirt`)

- **Type** : intermédiaire.
- **Armure** : 2.
- **Force conseillée** : 5.
- **Poids** : 10 kg.
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge).

### Cuirasse (`breastplate`)

- **Type** : intermédiaire.
- **Armure** : 2.
- **Force conseillée** : 5.
- **Poids** : 10 kg.
- **Valeur** : 80 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Cotte de mailles (`chain_mail`)

- **Type** : lourde.
- **Armure** : 3.
- **Force conseillée** : 6.
- **Poids** : 27 kg.
- **Valeur** : 15 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Guerrier.

### Harnois (`plate`)

- **Type** : lourde.
- **Armure** : 4.
- **Force conseillée** : 6.
- **Poids** : 32 kg.
- **Valeur** : 300 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Boucliers

### Bouclier (`shield`)

- **Armure** : +1 (permet de parer les attaques à distance).
- **Poids** : 3 kg.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Objets magiques

### Épée longue +1 (`longsword_plus_1`)

- **Dégâts** : tranchant, seuil de l'attaque +1.
- **Propriétés** : polyvalente (+1 au seuil à deux mains).
- **Effets** : +1 dé au toucher, +1 au seuil des dégâts.
- **Poids** : 1.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 120 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Sa lame ne s'émousse jamais et vibre légèrement au toucher.

### Langue de feu (`flame_tongue`)

- **Dégâts** : tranchant, seuil de l'attaque +1 + feu 2d10 ≤ 5.
- **Propriétés** : polyvalente (+1 au seuil à deux mains).
- **Poids** : 1.5 kg.
- **Rareté** : rare.
- **Valeur** : 400 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Une épée longue dont la lame s'embrase au moindre mouvement.

### Dague +1 (`dagger_plus_1`)

- **Dégâts** : perforant, seuil de l'attaque -1.
- **Propriétés** : finesse, légère, lancer.
- **Effets** : +1 dé au toucher, +1 au seuil des dégâts.
- **Poids** : 0.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 80 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Une lame fine, gravée de runes de précision.

### Cuir clouté +1 (`studded_leather_plus_1`)

- **Type** : légère.
- **Armure** : 1.
- **Force conseillée** : 4.
- **Effets** : +1 Armure.
- **Poids** : 6.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 120 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Un cuir enchanté, souple comme une seconde peau.

### Cape de protection (`cloak_of_protection`)

- **Emplacement** : cape.
- **Effets** : +1 Armure, +1 dé pour résister.
- **Poids** : 0.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 150 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Une cape grise qui détourne les coups et les sortilèges.

### Cape elfique (`elven_cloak`)

- **Emplacement** : cape.
- **Effets** : +2 rang en Furtivité.
- **Poids** : 0.5 kg.
- **Rareté** : peu commun.
- **Valeur** : 100 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Son capuchon se fond dans l'ombre et le feuillage.

### Anneau de protection (`ring_of_protection`)

- **Emplacement** : anneau.
- **Effets** : +1 Armure, +1 dé pour résister.
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
- **Effets** : +2 PV.
- **Poids** : 0.2 kg.
- **Rareté** : peu commun.
- **Valeur** : 100 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Un pendentif de chêne qui bat comme un cœur (+2 PV).

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
- **Effets** : +1 rang en Furtivité.
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

- Sac sans fond (capacité de charge), baguette de projectiles magiques, bâton de
  feu, amulette de santé, heaume de télépathie…

---

## Décisions (2026-10-13)

- Emplacements : couvre-chef, torse, cape, gants, jambes, chaussures, collier (1), anneaux (2). La cape a été
  rétablie (Cape de voyage, Cape de protection, Cape elfique) ; l'Anneau de protection reste.
- Pas de règle spéciale pour les armes à distance pour l'instant.
- Ni munitions ni usure.
- Pas de limite au nombre d'objets magiques portés.
- Améliorations élémentaires à la forge : plus tard.

## Questions ouvertes

1. **Colliers et anneaux** : on garde 1 collier et 2 anneaux, ou on autorise davantage ?
