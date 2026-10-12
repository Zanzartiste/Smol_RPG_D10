# Catalogue des classes — Lifantasy

> Document de conception : c'est ici qu'on décrit les classes (existantes et à venir) avant de les saisir dans
> `claude_rpg/data/classes.json` et `actions.json`. Les champs techniques sont détaillés dans
> [modele_donnees.md](modele_donnees.md).

## Règles générales

- Niveaux 1 à 20. La progression suit pour l'instant le **SRD 5.1** : emplacements de sorts, aptitudes, bonus de
  maîtrise.
- Améliorations aux niveaux 4, 8, 12, 16 et 20 : +1 à un attribut **et** un don (`rules.json › advancement`).
- Chaque classe maîtrise **deux jets de sauvegarde**.
- **Multiclassage** prévu : les niveaux d'amélioration et d'aptitudes se compteront par classe.
- Une classe **n'impose aucun métier**, mais certaines s'y prêtent mieux (bonus ou actions spéciales dans les
  sous-systèmes d'artisanat, de cuisine…).
- ⚠️ Licence : les classes du SRD 5.1 sont réutilisables (CC-BY 4.0). Les autres (Artificier, Alchimiste…) doivent
  être **conçues par nous**, sans recopier un livre hors SRD.
- **Pas encore géré** : sous-classes (et leur choix), actions bonus, réactions autres que l'Esquive instinctive, repos
  courts, choix des sorts appris (ils sont donnés par les aptitudes).

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Concept** : une phrase.
- **Statut** : disponible / à débloquer (indice, coût en Creator Points).
- **Dé de vie** : d6 / d8 / d10 / d12.
- **Priorité des attributs** (modèle d'achat de points) : ex. FOR > CON > DEX > SAG > CHA > INT.
- **Jets de sauvegarde maîtrisés** : deux attributs.
- **Compétences maîtrisées** : …
- **Équipement de départ** : arme, armure, objets.
- **Lanceur de sorts** : non / complet / demi — attribut d'incantation.
- **Actions de départ** : …
- **Métiers favorisés** : (facultatif) forge, alchimie, cuisine, commerce…

**Progression**

- Niveau 1 : …
- Niveau 2 : …
- Niveau 3 : …
- (une ligne par niveau qui apporte quelque chose)

**Sous-classes** : …

**Notes** : équilibrage, idées d'événements propres à la classe…
```

---

## Classes implémentées

### Guerrier (`fighter`)

- **Concept** : maître des armes et des armures, il règle les problèmes de front.
- **Statut** : disponible.
- **Dé de vie** : d10.
- **Priorité des attributs** : FOR > CON > DEX > SAG > CHA > INT.
- **Jets de sauvegarde maîtrisés** : Force, Constitution.
- **Compétences maîtrisées** : Athlétisme, Perception, Survie.
- **Équipement de départ** : épée longue, cotte de mailles, une potion de soins.
- **Lanceur de sorts** : non.
- **Actions de départ** : Attaque, Second souffle, Posture défensive, Coup de pommeau.

**Progression** (implémentée)

- Niveau 2 : Fougue (une action de plus, une fois par combat).
- Niveau 5 : Attaque supplémentaire (deux coups par action Attaque).
- Niveau 9 : Inflexible (relance automatique d'un jet de sauvegarde raté, une fois par repos long).
- Niveau 11 : Attaque supplémentaire (trois coups).
- Niveau 13 : Inflexible (deux utilisations).
- Niveau 17 : Inflexible (trois utilisations).
- Niveau 20 : Attaque supplémentaire (quatre coups).

**À venir (SRD)** : Style de combat au niveau 1, archétype martial au niveau 3 (Champion dans le SRD : critique sur
19-20…).

### Magicien (`wizard`)

- **Concept** : érudit des arcanes, fragile mais redoutable.
- **Statut** : disponible.
- **Dé de vie** : d6.
- **Priorité des attributs** : INT > CON > DEX > SAG > CHA > FOR.
- **Jets de sauvegarde maîtrisés** : Intelligence, Sagesse.
- **Compétences maîtrisées** : Arcanes, Investigation, Médecine.
- **Équipement de départ** : bâton.
- **Lanceur de sorts** : complet, Intelligence.
- **Actions de départ** :
  - tours de magie : Trait de feu, Rayon de givre ;
  - sorts du 1er niveau : Projectile magique, Mains brûlantes, Bouclier, Appel du familier.

**Progression** (implémentée)

- Emplacements de sort : table du lanceur complet (voir plus bas).
- Niveau 3 : Rayons ardents (sort du 2e niveau).
- Niveau 5 : Boule de feu (sort du 3e niveau), et tours de magie à deux dés.
- Niveau 11 : tours de magie à trois dés.
- Niveau 17 : tours de magie à quatre dés.

**À venir (SRD)** : Restauration arcanique (demande les repos courts), tradition arcanique au niveau 2 (Évocation dans
le SRD), sorts des niveaux 4 à 9, choix des sorts appris.

### Roublard (`rogue`)

- **Concept** : discret, agile et beau parleur. Les serrures n'ont pas de secret pour lui.
- **Statut** : à débloquer (« Réussir un larcin audacieux à Brumeval », ou 10 Creator Points).
- **Dé de vie** : d8.
- **Priorité des attributs** : DEX > CON > CHA > SAG > INT > FOR.
- **Jets de sauvegarde maîtrisés** : Dextérité, Intelligence.
- **Compétences maîtrisées** : Discrétion, Escamotage, Acrobaties, Perception.
- **Équipement de départ** : rapière, armure de cuir.
- **Lanceur de sorts** : non.
- **Actions de départ** : Attaque, Attaque sournoise, Lame empoisonnée.

**Progression** (implémentée)

- Niveau 1 : Expertise en Discrétion et en Escamotage (maîtrise doublée) ; Attaque sournoise à 1d6.
- Niveaux 3, 5, 7… 19 : l'Attaque sournoise gagne 1d6 (10d6 au niveau 19).
- Niveau 5 : Esquive instinctive (une attaque par round divisée par deux).
- Niveau 6 : Expertise en Acrobaties et en Perception.
- Niveau 7 : Dérobade (sauvegarde de DEX : rien si réussie, moitié si ratée).
- Niveau 11 : Talent fiable (pas moins de 10 au d20 pour une compétence maîtrisée).

**À venir (SRD)** : Ruse au niveau 2 (demande les actions bonus), archétype au niveau 3 (Voleur dans le SRD),
Coup de chance au niveau 20, choix des compétences d'Expertise.

---

## Emplacements de sort (SRD 5.1)

Lanceur complet (Magicien, et plus tard Clerc, Druide, Barde, Ensorceleur), emplacements par niveau de sort :

- Niveau 1 : 2 du 1er
- Niveau 2 : 3 du 1er
- Niveau 3 : 4 du 1er, 2 du 2e
- Niveau 4 : 4 du 1er, 3 du 2e
- Niveau 5 : 4 / 3 / 2 (jusqu'au 3e)
- Niveau 6 : 4 / 3 / 3
- Niveau 7 : 4 / 3 / 3 / 1 (jusqu'au 4e)
- Niveau 8 : 4 / 3 / 3 / 2
- Niveau 9 : 4 / 3 / 3 / 3 / 1 (jusqu'au 5e)
- Niveau 10 : 4 / 3 / 3 / 3 / 2
- Niveaux 11 et 12 : 4 / 3 / 3 / 3 / 2 / 1 (jusqu'au 6e)
- Niveaux 13 et 14 : … / 1 du 7e
- Niveaux 15 et 16 : … / 1 du 8e
- Niveau 17 : 4 / 3 / 3 / 3 / 2 / 1 / 1 / 1 / 1 (jusqu'au 9e)
- Niveau 18 : 4 / 3 / 3 / 3 / 3 / 1 / 1 / 1 / 1
- Niveau 19 : 4 / 3 / 3 / 3 / 3 / 2 / 1 / 1 / 1
- Niveau 20 : 4 / 3 / 3 / 3 / 3 / 2 / 2 / 1 / 1

Demi-lanceur (Paladin, Rôdeur) : rien au niveau 1, puis 2 du 1er au niveau 2, et ainsi de suite jusqu'au 5e niveau
de sort. La table complète est dans `rules.json › spell_slots › half`.

---

## Classes candidates (à compléter)

### Clerc (SRD)

- **Rôle envisagé** : soins, protection, magie divine.
- **Métiers favorisés** : médecine, temple.
- **Priorité** : ?

### Rôdeur (SRD)

- **Rôle envisagé** : combat à distance, nature, pistage ; demi-lanceur.
- **Métiers favorisés** : chasse, guide.
- **Priorité** : ?

### Barbare (SRD)

- **Rôle envisagé** : encaisser les coups, rage.
- **Métiers favorisés** : —
- **Priorité** : ?

### Barde (SRD)

- **Rôle envisagé** : soutien, social, magie.
- **Métiers favorisés** : spectacle, commerce.
- **Priorité** : ?

### Druide (SRD)

- **Rôle envisagé** : nature, métamorphose.
- **Métiers favorisés** : herboristerie.
- **Priorité** : ?

### Moine (SRD)

- **Rôle envisagé** : combat à mains nues, mobilité.
- **Métiers favorisés** : —
- **Priorité** : ?

### Paladin (SRD)

- **Rôle envisagé** : combattant sacré ; demi-lanceur.
- **Métiers favorisés** : —
- **Priorité** : ?

### Ensorceleur (SRD)

- **Rôle envisagé** : magie innée.
- **Métiers favorisés** : —
- **Priorité** : ?

### Occultiste (SRD)

- **Rôle envisagé** : pacte avec une entité, peu de sorts mais rechargés souvent.
- **Métiers favorisés** : —
- **Priorité** : ?

### Artificier (à concevoir)

- **Rôle envisagé** : inventions, objets, tourelles.
- **Métiers favorisés** : forge, artisanat.
- **Priorité** : ?

### Alchimiste (à concevoir)

- **Rôle envisagé** : potions, bombes, mutagènes.
- **Métiers favorisés** : alchimie, cuisine.
- **Priorité** : ?
