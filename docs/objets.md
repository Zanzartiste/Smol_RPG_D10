# Catalogue des objets — Lifantasy

> Document de conception : il recense les **objets qui restent dans le sac** (consommables, matériaux, trésors)
> qui doivent exister dans le jeu, avant leur saisie dans `claude_rpg/data/items.json`. Les armes, armures et
> accessoires sont dans [equipements.md](equipements.md).

## Règles générales

- **Catégories** :
  - **consommable** : s'utilise et disparaît (potions, antidotes…) ;
  - **matériau** : sert à fabriquer (forge, alchimie) et se revend ;
  - **trésor** : n'a pas d'usage, sinon d'être vendu (ou de déclencher des événements).
- Le **sac est partagé** par le groupe. Chaque objet a un **poids** (kg) ; au-delà de la capacité du groupe (7,5 kg
  par point de Force de chaque membre, objets portés compris), tout le groupe est encombré (voir
  [equipements.md](equipements.md)).
- L'inventaire a des **filtres** (Tout, Équipement, Consommables, Matériaux, Trésors, Quête) et une **recherche**.
- **Objets de quête** (`"quest": true`) : ni vendus ni jetés.
- **Hors combat**, seuls les objets de soins s'utilisent ; en combat, utiliser un objet prend l'action du tour.
- **Revente** : 50 % de la valeur, ajustée par la Persuasion (jusqu'à ±15 %). Tout marchand rachète tout, sauf les
  objets de quête.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Catégorie** : consommable / matériau / trésor.
- **Effet** : (consommable) soins, retrait d'un état, bonus temporaire…
- **Sert à fabriquer** : (matériau) …
- **Valeur** : en po.
- **Poids** : en kg.
- **Quête** : oui / non (un objet de quête ne se vend ni ne se jette).
- **Où le trouver** : boutique, récolte, butin, événement…
- **Description** : une phrase d'ambiance.
```

---

## Consommables

### Potion de soins (`potion_heal`)

- **Effet** : soigne 2d4+2 PV (en combat ou hors combat).
- **Valeur** : 10 po.
- **Poids** : 0.25 kg.
- **Où le trouver** : vendu par Herboristerie de Maëlle, fabriqué (alchimie), départ : Guerrier, événement « Jour de marché », événement « Un visage familier ».
- **Description** : Une fiole rouge qui referme les plaies.

### Antidote (`antidote`)

- **Effet** : retire l'état Poison (en combat seulement).
- **Valeur** : 8 po.
- **Poids** : 0.25 kg.
- **Où le trouver** : vendu par Herboristerie de Maëlle.
- **Description** : Un remède amer qui neutralise les poisons.

---

## Matériaux

### Herbes médicinales (`healing_herbs`)

- **Sert à fabriquer** : Potion de soins.
- **Valeur** : 2 po.
- **Poids** : 0.1 kg.
- **Où le trouver** : vendu par Herboristerie de Maëlle, événement « Sous les frondaisons », événement « Une clairière fleurie ».
- **Description** : Sauge et achillée, prisées des guérisseurs.

### Peau de loup (`wolf_pelt`)

- **Sert à fabriquer** : Cuir clouté.
- **Valeur** : 3 po.
- **Poids** : 2 kg.
- **Où le trouver** : butin : Loup (100 %), butin : Alpha des loups (100 %), événement « Un loup gris », événement « Jour de marché ».
- **Description** : Rêche et odorante, mais les tanneurs l'achètent.

### Minerai de fer (`iron_ore`)

- **Sert à fabriquer** : Dague, Hachette, Épée courte, Épée longue, Chemise de mailles, Cuir clouté.
- **Valeur** : 1 po.
- **Poids** : 2 kg.
- **Où le trouver** : vendu par Forge de Brumeval.
- **Description** : Un bloc de roche veinée de rouille, prêt pour la forge.

---

## Trésors

### Amulette ancienne (`old_amulet`)

- **Valeur** : 40 po.
- **Poids** : 0.25 kg.
- **Où le trouver** : événement « Le feu follet », événement « Jour de marché ».
- **Description** : Un bijou terni gravé de runes inconnues.

---

## Recettes d'alchimie

- **Potion de soins** : Herbes médicinales ×2, 2 po (chez l'herboriste).

---

## Objets candidats (à compléter)

### Consommables

- Potions de soins supérieure et majeure, potion de résistance (à un type de dégâts), potion de force de géant,
  huile d'arme (ajoute du feu ou du poison pour un combat), parchemins de sort, bombes alchimiques, rations et
  repas (bonus temporaires, voir la cuisine).

### Matériaux

- Lingot de fer, cuir tanné, bois, gemmes, minerais rares, plantes (pour l'alchimie), parties de monstres.

### Trésors et objets de quête

- Bijoux, œuvres d'art, lettres, clés, reliques liées aux vies passées (héritage).

---

## Décisions (2026-10-13)

- Poids maximal porté selon la Force (fait).
- Objets de quête : oui (faits : ni vendus ni jetés) ; filtres et recherche dans l'inventaire (faits).
- Pas d'objets périssables.
- Récolte de matériaux : oui (à faire, par des événements et des activités).
- Identification des objets mystérieux : à prévoir (par Arcanes ou chez un érudit).
- Héritage : en général, aucun objet ne passe d'une vie à la suivante.
- Fabrication : un jet de compétence (Artisanat, Potions et cuisine…), détails avec les métiers.

## Questions ouvertes

1. **Exceptions à l'héritage** : des objets légendaires ou des reliques liées au monde (et non au personnage)
   peuvent-ils rester d'une vie à l'autre, par exemple cachés quelque part ?
