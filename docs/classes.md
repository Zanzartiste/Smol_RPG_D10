# Catalogue des classes — Lifantasy

> Document de conception : c'est ici qu'on décrit les classes (existantes et à venir) avant de les saisir dans
> `claude_rpg/data/classes.json` et `actions.json`. Les champs techniques sont détaillés dans
> [modele_donnees.md](modele_donnees.md).

**Règles générales**
- Niveaux 1 à 20. La progression suit pour l'instant les tables du **SRD 5.1** (emplacements de sorts, aptitudes,
  bonus de maîtrise).
- Améliorations aux niveaux 4, 8, 12, 16 et 20 : +1 à un attribut **et** un don (`rules.json › advancement`).
- **Multiclassage** prévu : les niveaux d'amélioration se comptent par classe (ex. « niveau 4 de Guerrier »).
- Une classe **n'a aucun lien imposé avec un métier**, mais certaines s'y prêtent mieux (bonus, actions spéciales
  dans les sous-systèmes d'artisanat, de cuisine…).
- ⚠️ Licence : les classes du SRD 5.1 sont réutilisables (CC-BY 4.0). Les autres (ex. Artificier) doivent être
  **conçues par nous**, sans recopier un livre non-SRD.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)
- **Concept** : une phrase.
- **Statut** : disponible / à débloquer (indice, coût en Creator Points).
- **Dé de vie** : d6 / d8 / d10 / d12.
- **Priorité des attributs** (modèle d'achat de points) : ex. FOR > CON > DEX > SAG > CHA > INT.
- **Jets de sauvegarde maîtrisés** : 2 attributs.
- **Compétences** : N au choix parmi …
- **Équipement de départ** : arme, armure, objets.
- **Lanceur de sorts** : non / complet / demi / tiers / pacte — attribut d'incantation.
- **Ressources** : emplacements, utilisations par combat ou par repos…
- **Métiers favorisés** : (facultatif) forge, alchimie, cuisine, commerce…

| Niveau | Aptitudes / actions gagnées |
|---|---|
| 1 | … |
| 2 | … |
| … | … |

**Sous-classes** (niveau 3 dans le SRD) : …
**Notes** : équilibrage, idées d'événements propres à la classe…
```

---

## Classes implémentées

### Guerrier (`fighter`)
- **Concept** : maître des armes et des armures, il règle les problèmes de front.
- **Statut** : disponible.
- **Dé de vie** : d10. **Priorité** : FOR > CON > DEX > SAG > CHA > INT.
- **Compétences** : Athlétisme, Perception, Survie. **Équipement** : épée longue, cotte de mailles.
- **Actions actuelles** : attaque d'arme, Second souffle, Posture défensive, Coup de pommeau.

| Niveau | Aptitudes (SRD, à valider) |
|---|---|
| 1 | Style de combat, Second souffle |
| 2 | Fougue (une action supplémentaire, 1 fois par repos) |
| 3 | Archétype martial (sous-classe) |
| 5 | Attaque supplémentaire (2 attaques) |
| 9 | Inflexible (relancer un jet de sauvegarde raté) |
| 11 | Attaque supplémentaire (3 attaques) |
| 20 | Attaque supplémentaire (4 attaques) |

### Magicien (`wizard`)
- **Concept** : érudit des arcanes, fragile mais redoutable.
- **Statut** : disponible.
- **Dé de vie** : d6. **Priorité** : INT > CON > DEX > SAG > CHA > FOR. **Incantation** : Intelligence, lanceur complet.
- **Compétences** : Arcanes, Investigation, Médecine. **Équipement** : bâton.
- **Actions actuelles** : attaque d'arme, Trait de feu, Rayon de givre, Projectile magique (emplacement), invocation
  d'un familier.
- **Ressources actuelles** : 2 emplacements (non dépendants du niveau pour l'instant).

| Niveau | Aptitudes (SRD, à valider) |
|---|---|
| 1 | Incantation, Restauration arcanique |
| 2 | Tradition arcanique (sous-classe : École d'évocation dans le SRD) |
| 5 / 11 / 17 | Les sorts mineurs gagnent un dé de dégâts |
| 18 | Maîtrise des sorts |
| 20 | Sorts de prédilection |

### Roublard (`rogue`)
- **Concept** : discret, agile et beau parleur.
- **Statut** : à débloquer (« Réussir un larcin audacieux à Brumeval », ou 10 Creator Points).
- **Dé de vie** : d8. **Priorité** : DEX > CON > CHA > SAG > INT > FOR.
- **Compétences** : Discrétion, Escamotage, Acrobaties, Perception. **Équipement** : rapière.

| Niveau | Aptitudes (SRD, à valider) |
|---|---|
| 1 | Attaque sournoise (1d6, +1d6 tous les 2 niveaux), Expertise |
| 2 | Ruse (action bonus : se cacher, se désengager, foncer) |
| 3 | Archétype (sous-classe : Voleur dans le SRD) |
| 5 | Esquive instinctive (réaction : dégâts divisés par deux) |
| 7 | Dérobade (dégâts de zone évités) |
| 11 | Talent fiable |
| 20 | Coup de chance |

---

## Emplacements de sorts (SRD 5.1, lanceur complet)

Décision : on suit cette table. Les demi-lanceurs (Paladin, Rôdeur) utilisent la moitié de leur niveau, arrondie
au supérieur à partir du niveau 2.

| Niveau | 1er | 2e | 3e | 4e | 5e | 6e | 7e | 8e | 9e |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | | | | | | | | |
| 2 | 3 | | | | | | | | |
| 3 | 4 | 2 | | | | | | | |
| 4 | 4 | 3 | | | | | | | |
| 5 | 4 | 3 | 2 | | | | | | |
| 6 | 4 | 3 | 3 | | | | | | |
| 7 | 4 | 3 | 3 | 1 | | | | | |
| 8 | 4 | 3 | 3 | 2 | | | | | |
| 9 | 4 | 3 | 3 | 3 | 1 | | | | |
| 10 | 4 | 3 | 3 | 3 | 2 | | | | |
| 11–12 | 4 | 3 | 3 | 3 | 2 | 1 | | | |
| 13–14 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | | |
| 15–16 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | |
| 17 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | 1 |
| 18 | 4 | 3 | 3 | 3 | 3 | 1 | 1 | 1 | 1 |
| 19 | 4 | 3 | 3 | 3 | 3 | 2 | 1 | 1 | 1 |
| 20 | 4 | 3 | 3 | 3 | 3 | 2 | 2 | 1 | 1 |

---

## Classes candidates (à compléter par l'auteur)

| Classe | Source | Rôle envisagé | Métiers favorisés | Priorité |
|---|---|---|---|---|
| Clerc | SRD | Soins, protection, divin | Médecine, temple | ? |
| Rôdeur | SRD | Distance, nature, pistage | Chasse, guide | ? |
| Barbare | SRD | Encaisseur, rage | — | ? |
| Barde | SRD | Soutien, social | Spectacle, commerce | ? |
| Druide | SRD | Nature, métamorphose | Herboristerie | ? |
| Moine | SRD | Mains nues, mobilité | — | ? |
| Paladin | SRD | Combattant sacré, demi-lanceur | — | ? |
| Ensorceleur | SRD | Magie innée | — | ? |
| Occultiste | SRD | Pacte, sorts courts | — | ? |
| Artificier | **à concevoir** | Inventions, objets, tourelles | Forge, artisanat | ? |
| Alchimiste | **à concevoir** | Potions, bombes, mutagènes | Alchimie, cuisine | ? |
| … | | | | |
