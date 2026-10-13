# Types de dégâts — Lifantasy

> Document de conception : c'est ici qu'on décide des types de dégâts avant de les saisir dans
> `claude_rpg/data/damage_types.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md)
> (rubriques Défenses et Effets de combat).

## Règles actuelles

- Chaque attaque, sort ou état qui blesse a **un** type de dégâts. (Exemple, un coup d'épée enflammée pourrait infliger 1d6 tranchant + 1D4 feu)
  → **Implémenté** : une attaque ou une arme peut ajouter des dégâts d'autres types (`bonus_damage`). Chaque partie
  est lancée séparément et subit les défenses de son type. Exemple en jeu : la **Langue de feu** (épée longue,
  1d8 tranchant + 2d6 feu).
- Un type peut avoir un **état associé**, avec une chance de l'infliger à chaque fois qu'il blesse
  (`damage_types.json › status`). Les dégâts infligés par les états eux-mêmes ne le déclenchent pas.
- Une créature ou un personnage peut être, pour chaque type :
  - **résistant** : dégâts divisés par deux (arrondi à l'inférieur) ;
  - **immunisé** : aucun dégât ;
  - **vulnérable** : dégâts doublés.
  Résistance et vulnérabilité au même type s'annulent.
- Ces défenses viennent de l'espèce, des dons, de l'équipement (ex. l'Anneau de résistance au feu), des événements
  (effet `add_defense`) ou du bestiaire (`defenses` d'une créature).
- Trois types sont **physiques** (contondant, perforant, tranchant). Le jeu ne s'en sert pas encore.
- 12 types, issus du SRD 5.1 ; l'Acide a été fondu dans le Poison (2026-10-13).
- Chaque type a une **couleur**, utilisée dans le journal de combat (`damage_types.json › color`).

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
- **Sources** : mains nues, gourdin, bâton, masse d'armes...
- **État associé** : le Coup de pommeau du Guerrier étourdit (il passe par l'arme, pas par le type).
- **Qui y résiste…** : personne pour l'instant.

### Perforant (`piercing`)

- **Physique** : oui.
- **Description** : pointes, crocs, flèches.
- **Sources** : dague, épée courte, rapière, arcs 
- **Qui y résiste…** : personne pour l'instant.

### Tranchant (`slashing`)

- **Physique** : oui.
- **Description** : lames et griffes.
- **Sources** : hachette, cimeterre, épée longue, hache... ; la Langue de feu (avec du feu en plus).
- **Qui y résiste…** : personne pour l'instant.

### Feu (`fire`)

- **Physique** : non.
- **Description** : flammes, chaleur, explosions.
- **Sources** : Trait de feu, Mains brûlantes, Rayons ardents, Boule de feu ; l'état Brûlure (dégâts de feu à chaque tour) ; la Langue de feu.
- **État associé** : Brûlure (tout dégât de feu a des chances d'infliger l'état).
  → **Implémenté** : 25 % de chances d'infliger 1 charge de Brûlure (valeur provisoire, réglable dans
  `damage_types.json`). Mains brûlantes l'inflige en plus à coup sûr si la cible rate sa sauvegarde.
- **Qui y résiste…** : tieffelins, don Adepte élémentaire, Anneau de résistance au feu.


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
- **Sources** : l'état Poison, qui inflige désormais de **vrais dégâts de poison** (décision du 2026-10-13) : la
  résistance les divise par deux, l'immunité les annule, et la Protection les absorbe.
- **État associé** : Poison.
- **Qui y résiste…** : nains ; le don Résistant (qui immunise aussi contre l'état Poison).

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

## Décisions (2026-10-13)

- **Liste** : on pourra en supprimer ou en ajouter ; l'Acide est fondu dans le Poison pour l'instant (fait).
- **Réactions élémentaires** : probablement, sans aller aussi loin que Genshin.
- **Magique ou non** : possible ; à faire plus tard (marquer les armes magiques, défense « physique non magique »).
- **Environnement** : oui (pièges, météo, surfaces), par des événements, avec une incidence possible en combat.
- **Poison** : un vrai type, bloqué par la résistance (fait).
- **Un état par type** : probablement, mais on ne s'occupe pas des détails pour l'instant. Seul le feu enflamme.
- **Couleurs** : une couleur par type (fait, dans le journal de combat).

## Questions ouvertes

1. Quels types ajouter ou retirer quand le lore sera posé ?
