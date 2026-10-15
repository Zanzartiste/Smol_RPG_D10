# Catalogue des classes — Lifantasy

> Document de conception : c'est ici qu'on décrit les classes (existantes et à venir) avant de les saisir dans
> `claude_rpg/data/classes.json` et `actions.json`. Les champs techniques sont détaillés dans
> [modele_donnees.md](modele_donnees.md). La conception et la progression des classes suivent le tableur
> [Classes.ods](Classes.ods) (feuille 1 : progression ; feuille 2 : compétences initiales).

## Règles générales

- Niveaux 1 à 20.
- **Progression commune à toutes les classes** (tableur, feuille 1) :
  - Niveau 1 : le **don de classe**, qui définit la classe (voir [dons.md](dons.md)).
  - Tous les deux niveaux (2, 4, 6… 20) : +1 rang dans une compétence au choix (`rules.json › skill_points`), un
    rang au plus par compétence et par niveau.
  - Niveau 3 : la sous-classe.
  - Niveaux 6, 9, 12 et 16 : une aptitude de sous-classe.
  - Niveaux 5, 10, 15 et 20 : +1 à un attribut (`rules.json › advancement › ability_levels`).
  - **Dons de niveau** : il y en aura, à placer dans la courbe de progression (`advancement › feat_levels`, vide
    pour l'instant).
- **Pas de maîtrise de résistance** : résister est un simple test de compétence (voir
  [systeme_de_jeu.md](systeme_de_jeu.md)).
- **Compétences** : la classe donne **8 rangs** à la création (tableur, feuille 2), en plus du rang de départ, des
  4 rangs du passé et des 8 rangs libres ; aucune compétence ne dépasse 5 à la création (voir
  [competences.md](competences.md)).
- **Ancienne progression du SRD** (Fougue, Attaque supplémentaire, Inflexible, Attaque sournoise, Ruse, Esquive
  instinctive, Expertise, Dérobade, Talent fiable, sorts appris par niveau) : retirée des classes ; gardée comme
  idées de dons (voir [dons.md](dons.md)).
- **Statut** : une classe est disponible, ou à débloquer par un succès en jeu (pas de coût en Creator Points).
- **Multiclassage** (implémenté, libre) : à chaque niveau gagné, on choisit au hub la classe qui progresse. Les
  aptitudes et les améliorations se comptent par niveau de classe ; les emplacements de sort se cumulent (lanceurs
  complets + demi-lanceurs ÷ 2) ; les rangs de compétence de classe sont ceux de la classe qui en donne le plus.
- **Points de vie** : ils ne dépendent pas de la classe : (taille + 2) × Constitution + 7.
- **Économie d'actions** : deux actions par tour ; certaines actions sont gratuites (Rage, Fougue, Se cacher avec la
  Ruse) ; les actions gardées deviennent des réactions (esquive, parade, contre-attaque, contresort).
- **Armures** : aucune restriction par classe ; toute armure peut être portée. Sous la Force conseillée, le
  personnage est encombré.
- **Sous-classes** : au niveau 3, une par classe implémentée pour l'instant. Le choix s'ouvre au hub.
- **Choix d'aptitude** (Style de combat, Expertise…) : proposés au hub dès qu'on les obtient. Les compagnons
  arrivent avec leurs choix déjà faits.
- **Lanceurs de sorts** : chaque famille de magie a sa compétence d'incantation, qui remplace l'ancienne compétence
  Magie : arcanique → Érudition (INT), divine → Détermination (SAG), primale → Nature (SAG), artistique → Arts
  (CHA ou DEX).
- **Équipement de départ** : plus tard, il sera acheté dans une boutique à la création ; en attendant, chaque classe
  a un équipement fixe.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Concept** : une phrase.
- **Statut** : disponible / à débloquer (succès à réussir).
- **Priorité des attributs** (modèle de répartition) : ex. FOR > CON > DEX > SAG > CHA > INT.
- **Compétences** : Physique +2, Armes de mêlée +2… (8 rangs au total).
- **Lanceur de sorts** : non / complet / demi — compétence d'incantation.
- **Actions de départ** : …

**Progression**

- Niveau 1 : don de classe …
- Niveau 3 : sous-classe …
- Niveaux 6, 9, 12, 16 : aptitudes de sous-classe …

**Sous-classes** : …

**Notes** : équilibrage, idées d'événements propres à la classe…
```

---

## Classes implémentées

### Guerrier (`fighter`)

- **Concept** : maître des armes et des armures, il règle les problèmes de front.
- **Statut** : disponible.
- **Priorité des attributs** : FOR > CON > DEX > SAG > CHA > INT.
- **Compétences** : Armes de mêlée +2, Armes de trait +2, Physique +2, Machines de guerre +1, Détermination +1.
- **Équipement (provisoire)** : épée longue, cotte de mailles, une potion de soins.
- **Lanceur de sorts** : non.
- **Actions de départ** : Attaque, Second souffle, Posture défensive, Coup de pommeau.

**Progression**

- Niveau 1 : **Style de combat** (don de classe) : un don de style au choix, à une main, à mains nues, à deux armes,
  à deux mains ou à distance.
- Niveau 3 : sous-classe (à concevoir : le tableur ne propose rien encore ; pour l'instant, le Champion).

**Sous-classe : Champion** (SRD 5.2, provisoire)

- Niveau 3 : Critique amélioré (un succès de moins pour le critique) ; Athlète remarquable (deux d10 à
  l'initiative, un dé de plus en Physique).
- Niveau 7 : Style de combat supplémentaire.
- Niveau 10 : Guerrier héroïque (pas encore de mécanique).
- Niveau 15 : Critique supérieur.
- Niveau 18 : Survivant (début de tour à moitié de PV ou moins : récupère la moitié de sa CON en PV).

### Roublard (`rogue`)

- **Concept** : discret, agile et beau parleur. Les serrures n'ont pas de secret pour lui.
- **Statut** : disponible.
- **Priorité des attributs** : DEX > CON > CHA > SAG > INT > FOR.
- **Compétences** : Persuasion +2, Escamotage +2, Furtivité +2, Perception +2.
- **Équipement (provisoire)** : rapière, armure de cuir.
- **Lanceur de sorts** : non.
- **Actions de départ** : Attaque, Lame empoisonnée.

**Progression**

- Niveau 1 : **Attaques précises** (don de classe) : vos attaques critiques infligent 3 dés de dégâts
  supplémentaires.
- Niveau 3 : sous-classe. Pistes du tableur : Assassin, Éclaireur, Voleur, Duelliste ? Implémentée : Voleur.

**Sous-classe : Voleur** (SRD 5.2)

- Niveau 3 : Mains lestes (une fois par tour, utiliser un objet ne coûte pas l'action) ; Monte-en-l'air (+1 rang en
  Physique).
- Niveau 9 : Furtivité suprême (un dé de plus en Furtivité).
- Niveau 13 : Utilisation d'objets magiques (pas encore de mécanique).
- Niveau 17 : Réflexes de voleur (pas encore de mécanique).

### Barbare (`barbarian`)

- **Concept** : guerrier des terres sauvages, il puise dans sa fureur une force terrifiante.
- **Statut** : disponible.
- **Priorité des attributs** : FOR > CON > DEX > SAG > CHA > INT.
- **Compétences** : Armes de mêlée +2, Physique +2, Nature +2, Perception +1, Dressage +1.
- **Équipement (provisoire)** : hache à deux mains, armure de peaux, une potion de soins.
- **Lanceur de sorts** : non.
- **Actions de départ** : Attaque, Rage.

**Progression**

- Niveau 1 : **Rage** (don de classe) : action gratuite, jusqu'au début de votre prochain tour. Vous ne pouvez plus
  qu'attaquer au corps à corps, et les succès des jets d'attaque que vous faites **et** que vous subissez sont
  doublés.
- Niveau 3 : sous-classe (pistes : Berserker, Bête, « Lanceur »).

### Magicien (`wizard`)

- **Concept** : érudit des arcanes, fragile mais redoutable.
- **Statut** : à débloquer : « Lancer un sort à l'aide d'un parchemin » (parchemins vendus à l'herboristerie de
  Brumeval ; lus avec la compétence Langues).
- **Priorité des attributs** : INT > CON > DEX > SAG > CHA > FOR.
- **Compétences** : Détermination +2, Langues +2, Érudition +2, Alchimie +1, Médecine +1.
- **Équipement (provisoire)** : bâton, robe d'érudit.
- **Lanceur de sorts** : complet, Intelligence ; compétence d'incantation : Érudition.
- **Actions de départ** :
  - tours de magie : Trait de feu, Rayon de givre ;
  - sorts du 1er niveau : Projectile magique, Mains brûlantes, Sommeil, Bouclier, Appel du familier.

**Progression**

- Niveau 1 : **Sorts arcaniques** (don de classe) : vous lancez des sorts en puisant dans vos connaissances
  ésotériques de la magie ; ils utilisent la compétence Érudition (INT).
- Niveau 3 : sous-classe : une par catégorie de sorts (Nécromancien…). Implémentée : Évocateur.
- Emplacements de sort du lanceur complet ; tours de magie renforcés (niveaux 5, 11 et 17). Plus de sort appris
  par niveau pour l'instant (Rayons ardents et Boule de feu ne s'apprennent plus).

**Sous-classe : Évocateur** (SRD 5.2)

- Niveau 3 : Tour de magie puissant (un tour de magie raté inflige quand même la moitié des dégâts) ; Savant de
  l'évocation (pas encore de mécanique).
- Niveau 6 : Sculpture des sorts (déjà le cas : les sorts de zone épargnent les alliés).
- Niveau 10 : Évocation renforcée (un dé de plus aux sorts d'évocation).
- Niveau 14 : Surcharge (pas encore de mécanique).

---

## Classes prévues (tableur, à débloquer)

Les déblocages sont à définir. Les compétences sont les 8 rangs de la feuille 2.

### Rôdeur

- **Compétences** : Furtivité +2, Perception +2, Nature +2, Armes de trait +1, Physique +1.
- **Don de classe** : **Traque** : vous choisissez un ennemi ; tant que vous le traquez, tous vos jets qui le
  concernent ont un bonus de +1 (attaque…).
- **Sous-classes envisagées** : Maître des bêtes, Lanceur de sorts ?, Pisteur furtif, Chasseur classique, Gardien de
  l'essaim.

### Druide

- **Compétences** : Alchimie +2, Nature +2, Dressage +2, Persuasion +1, Médecine +1.
- **Don de classe** : **Sorts de druide** : vous lancez des sorts en puisant dans les pouvoirs de la nature ; ils
  utilisent la compétence Nature (SAG).
- **Sous-classes envisagées** : Invocateur, Métamorphe, Sorts de nature, Feu sauvage ?, Champignons.

### Clerc

- **Compétences** : Détermination +2, Perspicacité +2, Érudition +2, Médecine +2.
- **Don de classe** : **Sorts divins** : vous lancez des sorts en puisant dans les pouvoirs d'une divinité ou d'un
  domaine divin choisi ; ils utilisent la compétence Détermination (SAG).
- **Sous-classes envisagées** : divers dieux, divers domaines.

### Barde

- **Compétences** : Détermination +2, Persuasion +2, Perspicacité +2, Arts +2.
- **Don de classe** : **Représentations bardiques** : vous lancez des sorts en puisant dans vos talents
  artistiques ; ils utilisent la compétence Arts (CHA ou DEX).
- **Sous-classes envisagées** : Danseur (proche du moine), Savoir et sorts, Guerrier, « Barde des bardes ».

### Parangon

- **Compétences** : Armes de mêlée +2, Persuasion +2, Perspicacité +2, Érudition +1, Arts +1.
- **Don de classe** : à définir.

### Paysan

- **Compétences** : Physique +2, Nature +2, Dressage +2, Artisanat +1, Alchimie +1.
- **Don de classe** : à définir.

### Pistolier

- **Compétences** : Armes à poudre +2, Furtivité +2, Perception +2, Machines de guerre +1, Escamotage +1.
- **Don de classe** : à définir.

### Artificier

- **Compétences** : Érudition +2, Artisanat +2, Alchimie +2, Machines de guerre +1, Escamotage +1.
- **Don de classe** : à définir.

### Moine

- **Compétences** : Physique +2, Perspicacité +2, Furtivité +1, Perception +1, Érudition +1, Médecine +1.
- **Don de classe** : à définir.

### Autres idées (hors tableur)

- Paladin, Ensorceleur, Occultiste, Alchimiste : à reprendre ou à abandonner.

---

## Emplacements de sort (SRD 5.1)

Lanceur complet (Magicien), emplacements par niveau de sort :

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

Demi-lanceur : rien au niveau 1, puis 2 du 1er au niveau 2, et ainsi de suite jusqu'au 5e niveau de sort. La table
complète est dans `rules.json › spell_slots › half`.
