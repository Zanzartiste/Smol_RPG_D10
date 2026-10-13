# Catalogue des objets — Lifantasy

> Document de conception : il recense les **objets qui restent dans le sac** (consommables, matériaux, trésors)
> qui doivent exister dans le jeu, avant leur saisie dans `claude_rpg/data/items.json`. Les armes, armures et
> accessoires sont dans [equipements.md](equipements.md).

## Règles générales

- **Catégories** :
  - **consommable** : s'utilise et disparaît (potions, antidotes…) ;
  - **matériau** : sert à fabriquer (forge, alchimie) et se revend ;
  - **trésor** : n'a pas d'usage, sinon d'être vendu (ou de déclencher des événements).
- Le **sac est partagé** par le groupe ; les objets s'y cumulent sans limite de poids ni de place.
- **Hors combat**, seuls les objets de soins s'utilisent ; en combat, utiliser un objet prend l'action du tour.
- **Revente** : 50 % de la valeur, ajustée par la Persuasion (jusqu'à ±15 %). Chaque boutique ne rachète que
  certaines catégories (l'herboriste : consommables et matériaux ; la forge : matériaux, armes, armures, boucliers ;
  l'armurier : équipement).

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Catégorie** : consommable / matériau / trésor.
- **Effet** : (consommable) soins, retrait d'un état, bonus temporaire…
- **Sert à fabriquer** : (matériau) …
- **Valeur** : en po.
- **Où le trouver** : boutique, récolte, butin, événement…
- **Description** : une phrase d'ambiance.
```

---

## Consommables

### Potion de soins (`potion_heal`)

- **Effet** : soigne 2d4+2 PV (en combat ou hors combat).
- **Valeur** : 10 po.
- **Où le trouver** : vendu par Herboristerie de Maëlle, fabriqué (alchimie), départ : Guerrier, événement « Jour de marché », événement « Un visage familier ».
- **Description** : Une fiole rouge qui referme les plaies.

### Antidote (`antidote`)

- **Effet** : retire l'état Poison (en combat seulement).
- **Valeur** : 8 po.
- **Où le trouver** : vendu par Herboristerie de Maëlle.
- **Description** : Un remède amer qui neutralise les poisons.

---

## Matériaux

### Herbes médicinales (`healing_herbs`)

- **Sert à fabriquer** : Potion de soins.
- **Valeur** : 2 po.
- **Où le trouver** : vendu par Herboristerie de Maëlle, événement « Sous les frondaisons », événement « Une clairière fleurie ».
- **Description** : Sauge et achillée, prisées des guérisseurs.

### Peau de loup (`wolf_pelt`)

- **Sert à fabriquer** : Cuir clouté.
- **Valeur** : 3 po.
- **Où le trouver** : butin : Loup (100 %), butin : Alpha des loups (100 %), événement « Un loup gris », événement « Jour de marché ».
- **Description** : Rêche et odorante, mais les tanneurs l'achètent.

### Minerai de fer (`iron_ore`)

- **Sert à fabriquer** : Dague, Hachette, Épée courte, Épée longue, Chemise de mailles, Cuir clouté.
- **Valeur** : 1 po.
- **Où le trouver** : vendu par Forge de Brumeval.
- **Description** : Un bloc de roche veinée de rouille, prêt pour la forge.

---

## Trésors

### Amulette ancienne (`old_amulet`)

- **Valeur** : 40 po.
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

## Questions ouvertes

1. **Encombrement du sac** : on garde un sac illimité, ou on ajoute un poids ou un nombre de places ?
2. **Objets de quête** : des objets impossibles à vendre ou à jeter ?
3. **Durée de vie** : des objets qui se périment (nourriture, herbes fraîches) ?
4. **Récolte** : peut-on récolter des matériaux (cueillette, minage) par des événements ou des activités ?
5. **Identification** : des objets mystérieux à identifier (l'Amulette ancienne), par Arcanes ou chez un érudit ?
6. **Héritage** : quels objets passent d'une vie à la suivante (trésor familial, maison) ?
