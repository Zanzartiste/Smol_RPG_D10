# Catalogue de l'équipement — Lifantasy

> Document de conception : il recense les **armes, armures, boucliers et accessoires** (tout ce qui se porte) qui
> doivent exister dans le jeu, avant leur saisie dans `claude_rpg/data/equipment.json`. Les objets qui restent dans le
> sac (potions, matériaux, trésors) sont dans [objets.md](objets.md). Champs techniques :
> [modele_donnees.md](modele_donnees.md), rubriques Équipement et Économie.

## Règles générales

- **Emplacements** : main principale, main secondaire, couvre-chef, torse (armure, avec bras et épaules), cape,
  gants, jambes, chaussures, collier (1), anneaux (2).
- **Attaque** (voir [systeme_de_jeu.md](systeme_de_jeu.md)) : [rang de la compétence de l'arme] d10 contre la
  **DEX** de l'attaquant, quelle que soit l'arme ; la difficulté reste l'Esquive naturelle de la cible (mêlée) ou
  son Couvert (distance). Compétence : Armes de mêlée, Armes de trait, ou Physique (mains nues, poing américain,
  crochet, armes de jet, fronde).
- **Dégâts** : le **nombre de d10 de l'arme** (4 à 7, le rang de la compétence n'y entre plus), contre le **seuil
  de l'arme** : FOR (FOR +1 ou +2 pour les plus lourdes), DEX (fleuret, rapière, fronde, shuriken) ou un seuil fixe
  (arcs, arbalètes). Chaque succès est un point de dégâts.
- **Parade** : chaque arme a un **seuil de parade** (épée 4, dague 2, faux 1…) ; certaines en ont deux, à une main et
  à deux mains (bâton 2 ou 5). On pare avec [rang d'Armes de mêlée] d10 (Physique pour les armes de cette
  compétence) contre ce seuil. Une arme sans seuil (arc, arme de jet) ne pare pas. Bouclier : seuil 4, en mêlée
  comme contre un tir.
- **Une ou deux mains** : toute arme qui a un poids à une main peut se tenir d'une main, même une épée à deux mains
  (elle pèse alors plus lourd). On la tient à deux mains quand l'autre main est libre. Les arcs ne se tiennent qu'à
  deux mains.
- **Armures** : leurs points d'**Armure** baissent d'autant le seuil des dégâts subis (sans passer sous 1).
  L'armure se compte entière (du casque aux jambières) ; les accessoires (bottes, gants, cape…) ne pèsent rien.
- **Encombrement** = poids de l'armure + poids du bouclier + poids des armes en main (à une ou à deux mains)
  − FOR − CON + taille × 2 + armure naturelle × 2 (au moins 0 ; `rules.json › encumbrance`).
  - Chaque point d'encombrement retire **1 à la Dextérité** : attaques, Esquive naturelle (DEX ÷ 3), esquive,
    parade, initiative, tests et résistances de DEX.
  - À 0 de Dextérité, on ne peut plus agir dans cette armure (on passe son tour en combat).
  - Les prérequis (dons, conditions des événements) regardent la Dextérité hors encombrement.
  - Entraînement aux armures lourdes : encombrement −2.
  - Le poids des objets du sac ne compte plus (plus de charge du groupe), par simplicité.
- **Plusieurs types de dégâts** : une arme peut ajouter des dégâts d'un autre type (Langue de feu : tranchant + feu).
- **Prix** : environ un cinquième des prix du SRD, pour que la potion de soins coûte 10 po. **Tout marchand rachète
  tout** (sauf les objets de quête), à 50 % de la valeur. La Persuasion du meilleur négociateur du groupe ajuste les
  prix d'achat **et** de revente (jusqu'à ±15 %).
- **Forge** :
  - **Amélioration** d'une arme, d'une armure (pas d'un vêtement) ou d'un bouclier ordinaire : +1 (50 po), +2 (150 po),
    +3 (400 po). +N dés au toucher et aux dégâts pour une arme, +N Armure sinon. Les objets déjà
    magiques ne s'améliorent pas.
  - **Fabrication** à partir de matériaux (voir Recettes ci-dessous).

### Propriétés des armes

- **Parade dangereuse** (mains nues, poing américain, crochet ; crocs et griffes des bêtes) : parer avec elle une
  arme qui n'a pas cette propriété fait perdre 1 PV par dé qui donne 10 à la parade, même si la parade réussit.
  Les attaques à mains nues, de crocs ou de griffes ont aussi cette propriété : on les pare sans risque.
- **À impact** (haches) : baisse de 1 le seuil de parade de l'adversaire.
- **Allonge** (lances, hallebarde) : frappe plus loin ; sans effet tant qu'il n'y a ni grille ni déplacement.
- **Assassine** (dague, couteau) : lors d'une attaque surprise, ignore l'armure de la cible (pas une armure
  naturelle). Les autres armes ne l'ignorent plus.
- **Imprévisible (X)** (armes improvisées, faux) : l'arme se brise après avoir infligé ses dégâts si le jet
  d'attaque fait au moins X dés à 10, même s'il est réussi.
- **Perçante** (fleuret, lances, faux, javelot, arcs, arbalètes) : sur un critique, 3 dégâts de plus.
- **Recharge N** (fronde 1, arbalètes 2 ou 3) : après chaque tir, il faut N actions « Recharger » avant de
  tirer de nouveau.
- **Arbalète** : si l'on a la force de la manier à une main (FOR au moins égale à son poids à une main), la recharge
  baisse de 1.
- **Torche** : dégâts de feu.
- **De lancer** (pierres, shuriken, javelot) : armes à distance de la compétence Physique, sans munitions.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Catégorie** : arme / armure (torse) / bouclier / accessoire (couvre-chef, cape, gants, jambes, chaussures, collier, anneau).
- **Compétence** (arme) : Armes de mêlée / Armes de trait / Physique.
- **Dégâts** (arme) : type, nombre de dés, seuil (FOR, FOR +1, DEX ou fixe), ex. tranchant, 7d10, seuil FOR.
- **Parade** (arme, bouclier) : seuil, ou « 2 à une main, 5 à deux mains », ou impossible.
- **Poids** : à une main et à deux mains pour une arme ; un seul pour une armure ou un bouclier.
- **Propriétés** (arme) : parade dangereuse, à impact, allonge, assassine, imprévisible (X), perçante, recharge N, de lancer.
- **Type et Armure** (armure) : vêtement / légère / intermédiaire / lourde, points d'Armure.
- **Effets** : bonus, résistances… (objets magiques).
- **Rareté** : commun / peu commun / rare / très rare / légendaire.
- **Valeur** : en po.
- **Où le trouver** : boutique, forge, butin, événement, quête…
- **Description** : une phrase d'ambiance.
```

---

## Armure naturelle

Elle s'ajoute à l'Armure de ce que l'on porte, et compte double dans l'encombrement. Exemples pour des créatures
sauvages (et pour une espèce jouable : `species.json › natural_armor`) :

- Peau nue : 0.
- Épaisse fourrure : 1.
- Écailles : 2.
- Couche épaisse de graisse : 3.
- Chitine d'insecte géant : 3.
- Écailles de dragon : 5.

---

## Armes

Source : `docs/Classes.ods`, feuille « Feuille5 » (armes). Fiches générées depuis `equipment.json`.

### Mains nues (`unarmed`)

- **Compétence** : Physique.
- **Dégâts** : contondant, 4d10, seuil FOR.
- **Parade** : 3.
- **Poids** : 2 à une main, 1 à deux mains.
- **Propriétés** : parade dangereuse.

### Poing américain (`brass_knuckles`)

- **Compétence** : Physique.
- **Dégâts** : contondant, 5d10, seuil FOR.
- **Parade** : 4.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : parade dangereuse.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Crochet (`hook`)

- **Compétence** : Physique.
- **Dégâts** : perforant, 5d10, seuil FOR.
- **Parade** : 3.
- **Poids** : 5 à une main, 3 à deux mains.
- **Propriétés** : parade dangereuse.
- **Valeur** : 1 po.
- **Où le trouver** : aucune pour l'instant (à placer).

### Couteau (`knife`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 4d10, seuil FOR.
- **Parade** : 1.
- **Poids** : 1.
- **Propriétés** : assassine.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arme improvisée moyenne (`improvised_medium`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 5d10, seuil FOR.
- **Parade** : 1.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : imprévisible (1).
- **Où le trouver** : aucune pour l'instant (à placer).

### Arme improvisée grande (`improvised_large`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 6d10, seuil FOR.
- **Parade** : 2.
- **Poids** : 6 à une main, 4 à deux mains.
- **Propriétés** : imprévisible (2).
- **Où le trouver** : aucune pour l'instant (à placer).

### Dague (`dagger`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 5d10, seuil FOR.
- **Parade** : 2.
- **Poids** : 2 à une main, 1 à deux mains.
- **Propriétés** : assassine.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (30 %), arme de : Brigand.

### Épée courte (`shortsword`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 6d10, seuil FOR.
- **Parade** : 4.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (15 %), arme de : Brigand.

### Épée longue (`longsword`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR.
- **Parade** : 4.
- **Poids** : 4 à une main, 3 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 3 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), départ : Guerrier.

### Épée bâtarde (`bastard_sword`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR +1.
- **Parade** : 4.
- **Poids** : 6 à une main, 4 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 6 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Épée à deux mains (`greatsword`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR +2.
- **Parade** : 3.
- **Poids** : 8 à une main, 5 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Fleuret (`foil`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 4d10, seuil DEX.
- **Parade** : 3.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : perçante (+3 dégâts sur un critique).
- **Valeur** : 4 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Rapière (`rapier`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 6d10, seuil DEX.
- **Parade** : 4.
- **Poids** : 4 à une main, 3 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Roublard.

### Hachette (`handaxe`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 6d10, seuil FOR.
- **Parade** : 3.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : à impact.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge).

### Hache de bûcheron (`woodcutter_axe`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR.
- **Parade** : 3.
- **Poids** : 5 à une main, 3 à deux mains.
- **Propriétés** : à impact.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Hache de bataille (`battleaxe`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR.
- **Parade** : 3.
- **Poids** : 6 à une main, 4 à deux mains.
- **Propriétés** : à impact.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Hache à deux mains (`greataxe`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR.
- **Parade** : 2.
- **Poids** : 8 à une main, 5 à deux mains.
- **Propriétés** : à impact.
- **Valeur** : 6 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Barbare, butin : Colosse tatoué (25 %).

### Bâton de bois (`quarterstaff`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 5d10, seuil FOR.
- **Parade** : 2 à une main, 5 à deux mains.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Magicien, arme de : Rebouteux des brigands.

### Bâton d'acier (`steel_staff`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 6d10, seuil FOR.
- **Parade** : 2 à une main, 5 à deux mains.
- **Poids** : 5 à une main, 4 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 4 po.
- **Où le trouver** : aucune pour l'instant (à placer).

### Massue en bois (`club`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 6d10, seuil FOR.
- **Parade** : 2.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Torche (`torch`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : feu, 7d10, seuil FOR.
- **Parade** : 2.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Marteau de guerre (`warhammer`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 6d10, seuil FOR.
- **Parade** : 3.
- **Poids** : 4 à une main, 2 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 3 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Masse d'armes (`mace`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 7d10, seuil FOR.
- **Parade** : 3.
- **Poids** : 5 à une main, 4 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Marteau à deux mains (`maul`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : contondant, 7d10, seuil FOR +2.
- **Parade** : 2.
- **Poids** : 8 à une main, 5 à deux mains.
- **Propriétés** : aucune.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Faux (`scythe`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 6d10, seuil FOR.
- **Parade** : 1 à une main, 4 à deux mains.
- **Poids** : 7 à une main, 4 à deux mains.
- **Propriétés** : perçante (+3 dégâts sur un critique), imprévisible (1).
- **Valeur** : 1 po.
- **Où le trouver** : aucune pour l'instant (à placer).

### Lance de fantassin (`spear`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 6d10, seuil FOR.
- **Parade** : 2 à une main, 5 à deux mains.
- **Poids** : 4 à une main, 3 à deux mains.
- **Propriétés** : allonge, perçante (+3 dégâts sur un critique).
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Lance de cavalerie (`lance`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 7d10, seuil FOR.
- **Parade** : 1 à une main, 4 à deux mains.
- **Poids** : 5 à une main, 4 à deux mains.
- **Propriétés** : allonge, perçante (+3 dégâts sur un critique).
- **Valeur** : 2 po.
- **Où le trouver** : aucune pour l'instant (à placer).

### Hallebarde (`halberd`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR +1.
- **Parade** : 1 à une main, 4 à deux mains.
- **Poids** : 7 à une main, 5 à deux mains.
- **Propriétés** : allonge, perçante (+3 dégâts sur un critique).
- **Valeur** : 4 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Petite pierre (`stone`)

- **Compétence** : Physique.
- **Dégâts** : contondant, 4d10, seuil FOR.
- **Parade** : impossible.
- **Poids** : 2 à une main, 1 à deux mains.
- **Propriétés** : à distance, de lancer.
- **Où le trouver** : aucune pour l'instant (à placer).

### Très grosse pierre (`large_stone`)

- **Compétence** : Physique.
- **Dégâts** : contondant, 6d10, seuil FOR.
- **Parade** : impossible.
- **Poids** : 7 à une main, 5 à deux mains.
- **Propriétés** : à distance, de lancer.
- **Où le trouver** : aucune pour l'instant (à placer).

### Fronde (`sling`)

- **Compétence** : Physique.
- **Dégâts** : contondant, 5d10, seuil DEX.
- **Parade** : impossible.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : à distance, recharge 1.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Shuriken (`shuriken`)

- **Compétence** : Physique.
- **Dégâts** : perforant, 4d10, seuil DEX.
- **Parade** : impossible.
- **Poids** : 1 à une main, 0 à deux mains.
- **Propriétés** : à distance, de lancer.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Javelot (`javelin`)

- **Compétence** : Physique.
- **Dégâts** : perforant, 5d10, seuil FOR.
- **Parade** : impossible.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : à distance, de lancer, perçante (+3 dégâts sur un critique).
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arc court (`shortbow`)

- **Compétence** : Armes de trait.
- **Dégâts** : perforant, 5d10, seuil fixe 5.
- **Parade** : impossible.
- **Poids** : 3 (à deux mains seulement).
- **Propriétés** : à distance, à deux mains seulement, perçante (+3 dégâts sur un critique).
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arc long (`longbow`)

- **Compétence** : Armes de trait.
- **Dégâts** : perforant, 6d10, seuil fixe 5.
- **Parade** : impossible.
- **Poids** : 4 (à deux mains seulement).
- **Propriétés** : à distance, à deux mains seulement, perçante (+3 dégâts sur un critique).
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arbalète de poing (`hand_crossbow`)

- **Compétence** : Armes de trait.
- **Dégâts** : perforant, 5d10, seuil fixe 4.
- **Parade** : impossible.
- **Poids** : 3 à une main, 2 à deux mains.
- **Propriétés** : à distance, arbalète, perçante (+3 dégâts sur un critique), recharge 2.
- **Valeur** : 15 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arbalète légère (`light_crossbow`)

- **Compétence** : Armes de trait.
- **Dégâts** : perforant, 6d10, seuil fixe 6.
- **Parade** : impossible.
- **Poids** : 5 à une main, 3 à deux mains.
- **Propriétés** : à distance, arbalète, perçante (+3 dégâts sur un critique), recharge 2.
- **Valeur** : 5 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Arbalète lourde (`heavy_crossbow`)

- **Compétence** : Armes de trait.
- **Dégâts** : perforant, 6d10, seuil fixe 7.
- **Parade** : impossible.
- **Poids** : 6 à une main, 4 à deux mains.
- **Propriétés** : à distance, arbalète, perçante (+3 dégâts sur un critique), recharge 3.
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Armures et vêtements

Source : `equipements.md` (liste du 2026-10-15). Le poids compte dans l'encombrement.

### Vêtements ordinaires (`clothes`)

- **Type** : vêtement.
- **Armure** : 0.
- **Poids** : 0.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Robe d'érudit (`robe`)

- **Type** : vêtement.
- **Armure** : 0.
- **Poids** : 0.
- **Valeur** : 2 po.
- **Où le trouver** : départ : Magicien.

### Armure rembourrée (`padded`)

- **Type** : légère.
- **Armure** : 1.
- **Poids** : 8.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Armure de cuir (`leather`)

- **Type** : légère.
- **Armure** : 1.
- **Poids** : 7.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, départ : Roublard, départ : Barbare.

### Armure de cuir bouilli ou clouté (`studded_leather`)

- **Type** : légère.
- **Armure** : 2.
- **Poids** : 9.
- **Valeur** : 9 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), butin : Brigand (10 %).

### Brigandine (`brigandine`)

- **Type** : intermédiaire.
- **Armure** : 3.
- **Poids** : 11.
- **Valeur** : 12 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Armure de mailles (`chain_mail`)

- **Type** : intermédiaire.
- **Armure** : 3.
- **Poids** : 10.
- **Valeur** : 15 po.
- **Où le trouver** : vendu par Armurerie de Gorvald, fabriqué (forge), départ : Guerrier.

### Armure d'écailles (`scale_mail`)

- **Type** : lourde.
- **Armure** : 4.
- **Poids** : 13.
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Cuirasse (`breastplate`)

- **Type** : lourde.
- **Armure** : 4.
- **Poids** : 12.
- **Valeur** : 80 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

### Armure de plates (`plate`)

- **Type** : lourde.
- **Armure** : 5.
- **Poids** : 14.
- **Valeur** : 300 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Boucliers

Tout bouclier donne +1 Armure et pare à 4, en mêlée comme contre un tir.

### Bouclier (`shield`)

- **Armure** : +1.
- **Parade** : 4, en mêlée comme contre un tir.
- **Poids** : 3.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Armurerie de Gorvald.

---

## Objets magiques

### Épée longue +1 (`longsword_plus_1`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR.
- **Parade** : 4.
- **Poids** : 4 à une main, 3 à deux mains.
- **Propriétés** : aucune.
- **Effets** : +1 dé au toucher, +1 dé de dégâts.
- **Rareté** : peu commun.
- **Valeur** : 120 po.
- **Où le trouver** : aucune pour l'instant (à placer).
- **Description** : Sa lame ne s'émousse jamais et vibre légèrement au toucher.

### Langue de feu (`flame_tongue`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : tranchant, 7d10, seuil FOR + feu 2d10 ≤ 5.
- **Parade** : 4.
- **Poids** : 4 à une main, 3 à deux mains.
- **Propriétés** : aucune.
- **Rareté** : rare.
- **Valeur** : 400 po.
- **Où le trouver** : aucune pour l'instant (à placer).
- **Description** : Une épée longue dont la lame s'embrase au moindre mouvement.

### Dague +1 (`dagger_plus_1`)

- **Compétence** : Armes de mêlée.
- **Dégâts** : perforant, 5d10, seuil FOR.
- **Parade** : 2.
- **Poids** : 2 à une main, 1 à deux mains.
- **Propriétés** : assassine.
- **Effets** : +1 dé au toucher, +1 dé de dégâts.
- **Rareté** : peu commun.
- **Valeur** : 80 po.
- **Où le trouver** : aucune pour l'instant (à placer).
- **Description** : Une lame fine, gravée de runes de précision.

### Cuir clouté +1 (`studded_leather_plus_1`)

- **Type** : légère.
- **Armure** : 2 (+1 enchantement).
- **Poids** : 9.
- **Rareté** : peu commun.
- **Valeur** : 120 po.
- **Où le trouver** : aucune pour l'instant (à placer).
- **Description** : Un cuir enchanté, souple comme une seconde peau.

### Cape de protection (`cloak_of_protection`)

- **Emplacement** : cape.
- **Effets** : +1 Armure, +1 dé pour résister.
- **Rareté** : peu commun.
- **Valeur** : 150 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Une cape grise qui détourne les coups et les sortilèges.

### Cape elfique (`elven_cloak`)

- **Emplacement** : cape.
- **Effets** : +2 rang en Furtivité.
- **Rareté** : peu commun.
- **Valeur** : 100 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Son capuchon se fond dans l'ombre et le feuillage.

### Anneau de protection (`ring_of_protection`)

- **Emplacement** : anneau.
- **Effets** : +1 Armure, +1 dé pour résister.
- **Rareté** : peu commun.
- **Valeur** : 150 po.
- **Où le trouver** : butin : Alpha des loups (100 %).
- **Description** : Un anneau d'argent qui détourne les coups et les sortilèges.

### Anneau de résistance au feu (`ring_fire_resistance`)

- **Emplacement** : anneau.
- **Effets** : résistance au feu.
- **Rareté** : rare.
- **Valeur** : 200 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Un anneau de cuivre toujours tiède.

### Amulette de vigueur (`amulet_vigor`)

- **Emplacement** : collier.
- **Effets** : +2 PV.
- **Rareté** : peu commun.
- **Valeur** : 100 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : Un pendentif de chêne qui bat comme un cœur (+2 PV).

### Gantelets de puissance d'ogre (`gauntlets_ogre_power`)

- **Emplacement** : gants.
- **Effets** : +2 FOR.
- **Rareté** : rare.
- **Valeur** : 300 po.
- **Où le trouver** : aucune pour l'instant (événements à écrire).
- **Description** : De lourds gantelets cloutés qui décuplent la poigne.

### Bottes elfiques (`elven_boots`)

- **Emplacement** : chaussures.
- **Effets** : +1 rang en Furtivité.
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
- **Armure de mailles** : Minerai de fer ×5, 3 po.
- **Cuir clouté** : Peau de loup ×2, Minerai de fer ×1, 1 po.

---

## Équipement candidat (à compléter)

### Armes du SRD manquantes

- Fléau, morgenstern, pic de guerre, glaive, coutille, trident, fouet, filet, sarbacane, cimeterre (retiré : il
  n'est pas dans la feuille des armes ; les anciennes sauvegardes le changent en épée courte).

### Armures du SRD manquantes

- Broigne, clibanion, demi-plate, armure à bandes. Retirées : armure de peau (devenue armure de cuir) et chemise de
  mailles (devenue armure de mailles).

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

## Décisions (2026-10-15, feuille des armes de Classes.ods)

- Dégâts : les dés de l'arme, sans le rang ; attaque contre la DEX ; parade contre le seuil de l'arme.
- Encombrement par le poids (armure, bouclier, armes) contre FOR + CON ; il retire de la DEX. Plus de charge du
  groupe.
- Choix faits en l'absence de précision (à valider) :
  1. « Parade 2 ou 5 » : 2 à une main, 5 à deux mains (même lecture pour le poids à une et à deux mains).
  2. Imprévisible (X) : X est le nombre de 10 qui brise l'arme (arme improvisée moyenne : un seul 10 ; grande : deux).
  3. Arbalète maniée à une main : FOR au moins égale à son poids à une main.
  4. Couteau et armes improvisées : poids non donnés, mis à 1 / 1 (couteau), 3 / 2 et 6 / 4 (improvisées).
     Bouclier : poids 3.
  5. Une arme sans seuil de parade (arcs, arbalètes, armes de jet) ne pare pas.
  6. Assassine : seule une arme assassine ignore l'armure lors d'une attaque surprise.
  7. Créatures : Griffes/crocs 5 dés, Crocs puissants 7 dés (loup sanguinaire), poing 4 dés ; elles attaquent
     contre leur DEX.
  8. Les armes de jet (pierres, shuriken, javelot) ne se perdent pas ; la dague, la hachette et la lance de
     fantassin ne se lancent pas encore (lancer une arme qu'on tient demanderait de la ramasser).
  9. Valeurs (prix) des nouvelles armes et armures : estimées, à corriger si besoin.
  10. Le bouclier ne sert pas encore d'arme improvisée (5 dés, seuil FOR).

## Décisions (2026-10-16)

- Les PV et les dégâts des armes restent tels quels, même si les combats deviennent plus courts.
- Le rang de compétence détermine si l'on touche ; l'attribut et l'arme déterminent les dégâts (pas de dé de plus
  avec le rang).
- Encombrement : à DEX 0, on ne peut plus agir ; il faut porter une armure plus légère.
- **Lancer** (fait) : en combat, le menu « Lancer » permet de lancer n'importe quel objet du sac ou l'arme tenue
  (une action, attaque à distance contre le Couvert). Une arme de lancer (pierres, shuriken, javelot, et désormais
  couteau, dague, hachette, lance de fantassin) garde ses dégâts ; le reste compte comme une arme improvisée
  (moyenne, ou grande à partir de 5 de poids). L'objet est perdu pour le reste du combat et ramassé après une
  victoire (l'arme revient dans sa main si elle est libre).
- **Munitions** : arcs et arbalètes tirent sans limite, sauf munitions spéciales (à venir).
- **Coup de bouclier** (fait) : avec un bouclier, l'action « Attaque et coup de bouclier » ajoute après l'attaque
  un coup de bouclier en main secondaire (5 dés, seuil FOR, contondant, −2 dés comme toute main secondaire). Choix
  fait (à valider) : le bouclier qui a frappé ne pare plus jusqu'au prochain tour.
- Armes improvisées : où les trouver reste à décider.
- Créatures armées : elles porteront armes et armures, avec l'encombrement (à faire).

## Questions ouvertes

1. **Colliers et anneaux** : on garde 1 collier et 2 anneaux, ou on autorise davantage ?
