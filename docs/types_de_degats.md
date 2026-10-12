# Types de dégâts — Lifantasy

> Document de conception : c'est ici qu'on décide des types de dégâts avant de les saisir dans
> `claude_rpg/data/damage_types.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md)
> (rubriques Défenses et Effets de combat).

## Règles actuelles

- Chaque attaque, sort ou état qui blesse a **un** type de dégâts.
- Une créature ou un personnage peut être, pour chaque type :
  - **résistant** : dégâts divisés par deux (arrondi à l'inférieur) ;
  - **immunisé** : aucun dégât ;
  - **vulnérable** : dégâts doublés.
  Résistance et vulnérabilité au même type s'annulent.
- Ces défenses viennent de l'espèce, des dons, de l'équipement (ex. l'Anneau de résistance au feu), des événements
  (effet `add_defense`) ou du bestiaire (`defenses` d'une créature).
- Trois types sont **physiques** (contondant, perforant, tranchant). Le jeu ne s'en sert pas encore.
- Les 13 types viennent du SRD 5.1.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Physique** : oui / non.
- **Description** : à quoi il ressemble, d'où il vient dans l'univers.
- **Sources** : armes, sorts, créatures, pièges, environnement…
- **État associé** : (facultatif) ex. le feu peut enflammer (Brûlure).
- **Qui y résiste / y est immunisé / y est vulnérable** : espèces, créatures, objets.
- **Couleur ou icône** : pour l'interface.
- **Notes** : …
```

---

## Types existants

### Contondant (`bludgeoning`)

- **Physique** : oui.
- **Description** : coups, chocs, chutes, écrasement.
- **Sources** : mains nues, gourdin, bâton, masse d'armes ; le Colosse tatoué.
- **État associé** : le Coup de pommeau du Guerrier étourdit (il passe par l'arme, pas par le type).
- **Qui y résiste…** : personne pour l'instant.

### Perforant (`piercing`)

- **Physique** : oui.
- **Description** : pointes, crocs, flèches.
- **Sources** : dague, épée courte, rapière, arcs ; morsures du loup, de l'Alpha, du rat géant et du familier.
- **Qui y résiste…** : personne pour l'instant.

### Tranchant (`slashing`)

- **Physique** : oui.
- **Description** : lames et griffes.
- **Sources** : hachette, cimeterre, épée longue (et +1), hache à deux mains ; le cimeterre du brigand.
- **Qui y résiste…** : personne pour l'instant.

### Feu (`fire`)

- **Physique** : non.
- **Description** : flammes, chaleur, explosions.
- **Sources** : Trait de feu, Mains brûlantes, Rayons ardents, Boule de feu ; l'état Brûlure (dégâts de feu à chaque
  tour).
- **État associé** : Brûlure (Mains brûlantes l'inflige).
- **Qui y résiste…** : le don Adepte élémentaire (magicien), l'Anneau de résistance au feu.

### Froid (`cold`)

- **Physique** : non.
- **Description** : gel, glace, souffle hivernal.
- **Sources** : Rayon de givre.
- **État associé** : Rayon de givre inflige Affaibli (dans le SRD, il ralentit).
- **Qui y résiste…** : personne pour l'instant.

### Force (`force`)

- **Physique** : non.
- **Description** : énergie magique pure ; presque rien n'y résiste.
- **Sources** : Projectile magique ; le loup spectral.
- **Qui y résiste…** : personne.

### Poison (`poison`)

- **Physique** : non.
- **Description** : venins et toxines.
- **Sources** : aucune attaque ne fait de dégâts de poison pour l'instant. L'état Poison inflige des dégâts **bruts**,
  qui ignorent les défenses.
- **État associé** : Poison.
- **Qui y résiste…** : le don Résistant (qui immunise aussi contre l'état Poison).

### Acide (`acid`)

- **Physique** : non.
- **Description** : corrosion.
- **Sources** : aucune pour l'instant.

### Foudre (`lightning`)

- **Physique** : non.
- **Description** : éclairs, électricité.
- **Sources** : aucune pour l'instant.

### Tonnerre (`thunder`)

- **Physique** : non.
- **Description** : onde de choc sonore.
- **Sources** : aucune pour l'instant.

### Nécrotique (`necrotic`)

- **Physique** : non.
- **Description** : énergie de mort, flétrissure.
- **Sources** : aucune pour l'instant.

### Radiant (`radiant`)

- **Physique** : non.
- **Description** : lumière sacrée, feu divin.
- **Sources** : aucune pour l'instant.

### Psychique (`psychic`)

- **Physique** : non.
- **Description** : attaque contre l'esprit.
- **Sources** : aucune pour l'instant.

---

## Questions ouvertes

1. **Liste des types** : on garde les 13 types du SRD, ou ton univers en demande d'autres (ex. ombre, arcane,
   sang…), ou moins (fusionner foudre et tonnerre…) ?
2. **Réactions élémentaires à la Genshin** : faut-il que les types interagissent ? Par exemple feu + froid = « fonte »
   (dégâts bonus), foudre sur une cible mouillée, feu qui retire Gelé… Ce serait une vraie signature du jeu, mais
   cela demande des états « élément appliqué ».
3. **Magique ou non** : dans D&D, beaucoup de monstres résistent aux dégâts physiques **non magiques**. On le gère ?
   Les armes +1 deviendraient alors importantes contre certains ennemis.
4. **Environnement** : pièges, chutes, météo, surfaces à la BG3 (huile qui s'enflamme, eau qui conduit la foudre) ?
   Sans positionnement, cela passerait plutôt par les événements et des états de terrain.
5. **Dégâts du poison** : on garde le Poison en dégâts bruts (qui ignorent les défenses), ou il devient un vrai type
   poison, bloqué par la résistance ?
6. **Lien type → état** : chaque type doit-il avoir une chance d'infliger un état par défaut (feu → Brûlure,
   froid → Ralenti, foudre → Étourdi…), ou seulement certaines actions comme aujourd'hui ?
7. **Interface** : une couleur ou une icône par type, dans le journal de combat et sur les fiches ?
