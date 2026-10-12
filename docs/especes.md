# Catalogue des espèces — Lifantasy

> Document de conception : c'est ici qu'on décrit les espèces (existantes et à venir) avant de les saisir dans
> `claude_rpg/data/species.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md).
> On dit **espèce**, jamais « race ».

## Règles générales

- Une espèce **ne modifie jamais les attributs**. Elle donne une taille, des âges, des noms, une apparence et
  éventuellement des traits (résistances, immunités, sens, actions).
- **Majorité à 18 ans pour toutes les espèces** (`rules.json › majority_age`) : un personnage jouable commence à 18 ans
  au moins, et l'étape « adulte » ne commence jamais avant 18 ans. Les événements « adultes » (romance, couple)
  exigent cet âge, quelle que soit l'espèce. Le validateur de données le vérifie.
- **Mariage** : aucune restriction entre espèces. En revanche, chaque espèce indique ce que donne sa **descendance**
  avec les autres (rubrique « Descendance » de chaque fiche).
- ⚠️ Licence : les espèces du SRD 5.1 sont réutilisables (CC-BY 4.0). Les autres sont à concevoir nous-mêmes.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Concept** : une ou deux phrases (apparence, culture, place dans le monde).
- **Statut** : disponible / à débloquer (indice, coût en Creator Points).
- **Taille** : Très petite / Petite / Moyenne / Grande (place au combat et taille du sprite : ½, 1 ou 2).
- **Âge de départ** : 18 ou plus.
- **Adolescent à** : …
- **Adulte à** : 18 ou plus.
- **Âgé à** : …
- **Vénérable à** : …
- **Vieillit à partir de** : … (chaque année au-delà retire 1 à un attribut au hasard)
- **Traits** : résistances, immunités, vision dans le noir, action propre…
- **Noms** : une dizaine d'exemples, et le style des noms (sonorités, nom de famille ou de clan…).
- **Apparence** : peau, cheveux, oreilles, signes distinctifs.
- **Descendance** :
  - avec la même espèce : …
  - avec une autre espèce : une des deux au hasard / une espèce hybride / selon un parent…
  - particularités : fertilité, durée de grossesse…
- **Lore** : origine, relations avec les autres espèces, attitude des PNJ.
```

---

## Espèces implémentées

### Humain (`human`)

- **Concept** : polyvalents et ambitieux, les humains sont partout.
- **Statut** : disponible.
- **Taille** : Moyenne.
- **Âge de départ** : 18.
- **Adolescent à** : 12.
- **Adulte à** : 18.
- **Âgé à** : 60.
- **Vénérable à** : 80.
- **Vieillit à partir de** : 60.
- **Traits** : aucun.
- **Noms** : Aldric, Brenna, Cédric, Daria, Edwin, Fiora, Gareth, Helna, Ivo, Jessa.
- **Descendance** : *à définir.*

### Gobelin (`goblin`)

- **Concept** : petits, vifs et rusés. On les dit voleurs ; ils préfèrent « opportunistes ».
- **Statut** : disponible.
- **Taille** : Petite.
- **Âge de départ** : 18 (relevé de 12 le 2026-10-12, pour la règle de majorité).
- **Adolescent à** : 10.
- **Adulte à** : 18.
- **Âgé à** : 40.
- **Vénérable à** : 55.
- **Vieillit à partir de** : 40.
- **Traits** : aucun pour l'instant.
- **Noms** : Grik, Zigzag, Nibblet, Grishka, Pustule, Rikkit, Vorna, Skarn, Mibz, Torgnole.
- **Descendance** : *à définir.*

### Elfe (`elf`)

- **Concept** : gracieux et d'une longévité prodigieuse, ils se tiennent à l'écart des affaires des mortels.
- **Statut** : à débloquer (« Percer le secret d'un sanctuaire oublié », ou 15 Creator Points).
- **Taille** : Moyenne.
- **Âge de départ** : 100.
- **Adolescent à** : 20.
- **Adulte à** : 100.
- **Âgé à** : 500.
- **Vénérable à** : 650.
- **Vieillit à partir de** : 500.
- **Traits** : immunisé contre le sommeil magique.
- **Descendance** : *à définir* (le SRD prévoit le demi-elfe avec un humain).

---

## Espèces candidates (à compléter)

### Nain (SRD)

- **Taille** : Moyenne.
- **Idée de trait** : résistance au poison.
- **Priorité** : ?

### Halfelin (SRD)

- **Taille** : Petite.
- **Idée de trait** : Chanceux (relance les 1 naturels).
- **Priorité** : ?

### Gnome (SRD)

- **Taille** : Petite.
- **Idée de trait** : avantage aux sauvegardes mentales contre la magie.
- **Priorité** : ?

### Demi-orc (SRD)

- **Taille** : Moyenne.
- **Idée de trait** : Endurance acharnée (tombe à 1 PV au lieu de 0, une fois).
- **Priorité** : ?

### Demi-elfe (SRD)

- **Taille** : Moyenne.
- **Idée de trait** : Polyvalence (compétences en plus).
- **Priorité** : ?

### Drakéide (SRD)

- **Taille** : Moyenne.
- **Idée de trait** : souffle et résistance selon l'ascendance draconique.
- **Priorité** : ?

### Tieffelin (SRD)

- **Taille** : Moyenne.
- **Idée de trait** : résistance au feu.
- **Priorité** : ?
