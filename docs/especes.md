# Catalogue des espèces — Lifantasy

> Document de conception : c'est ici qu'on décrit les espèces (existantes et à venir) avant de les saisir dans
> `claude_rpg/data/species.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md).
> On dit **espèce**, jamais « race ».

**Règles générales**
- Une espèce **ne modifie jamais les attributs**. Elle donne une taille, des âges, des noms, une apparence et
  éventuellement des traits (résistances, immunités, sens, actions).
- **Majorité à 18 ans pour toutes les espèces** (`rules.json › majority_age`) : un personnage jouable commence à 18 ans
  au moins, et l'étape « adulte » ne commence jamais avant 18 ans. Les événements « adultes » (romance, couple)
  exigent cet âge, quelle que soit l'espèce. Le validateur de données le vérifie.
- **Mariage** : aucune restriction entre espèces. En revanche, chaque espèce indique ce que donne sa **descendance**
  avec les autres (section « Descendance » de chaque fiche).
- ⚠️ Licence : les espèces du SRD 5.1 sont réutilisables (CC-BY 4.0). Les autres sont à concevoir nous-mêmes.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)
- **Concept** : une ou deux phrases (apparence, culture, place dans le monde).
- **Statut** : disponible / à débloquer (indice, coût en Creator Points).
- **Taille** : Très petite / Petite / Moyenne / Grande (échelle du sprite : ½, 1, 2).
- **Âges** : départ ≥ 18 · adolescent · adulte (≥ 18) · âgé · vénérable · vieillissement à partir de …
- **Traits** : résistances, immunités, vision dans le noir, action propre…
- **Noms** : une dizaine d'exemples, et le style des noms (sonorités, nom de famille ou de clan…).
- **Apparence** (pixel art puis IA) : peau, cheveux, oreilles, signes distinctifs.
- **Descendance** : avec la même espèce → … ; avec une autre → (une des deux au hasard / espèce hybride / selon la mère
  ou le père…) ; fertilité, durée de grossesse si différente.
- **Lore** : origine, relations avec les autres espèces, attitude des PNJ.
```

---

## Espèces implémentées

### Humain (`human`)
- **Concept** : polyvalents et ambitieux, les humains sont partout.
- **Statut** : disponible. **Taille** : Moyenne.
- **Âges** : départ 18 · ado 12 · adulte 18 · âgé 60 · vénérable 80 · vieillit dès 60 ans.
- **Traits** : aucun.
- **Descendance** : *à définir.*

### Gobelin (`goblin`)
- **Concept** : petits, vifs et rusés. On les dit voleurs ; ils préfèrent « opportunistes ».
- **Statut** : disponible. **Taille** : Petite.
- **Âges** : départ 18 · ado 10 · adulte 18 · âgé 40 · vénérable 55 · vieillit dès 40 ans.
  (Le départ à 12 ans et la majorité à 10 ans ont été relevés à 18 le 2026-10-12, pour la règle de majorité.)
- **Traits** : aucun pour l'instant.
- **Descendance** : *à définir.*

### Elfe (`elf`)
- **Concept** : gracieux et d'une longévité prodigieuse, ils se tiennent à l'écart des affaires des mortels.
- **Statut** : à débloquer (« Percer le secret d'un sanctuaire oublié », ou 15 Creator Points). **Taille** : Moyenne.
- **Âges** : départ 100 · ado 20 · adulte 100 · âgé 500 · vénérable 650 · vieillit dès 500 ans.
- **Traits** : immunisé contre le sommeil magique.
- **Descendance** : *à définir* (le SRD prévoit le demi-elfe avec un humain).

---

## Espèces candidates (à compléter par l'auteur)

| Espèce | Source | Taille | Idée de trait | Priorité |
|---|---|---|---|---|
| Nain | SRD | Moyenne | Résistance au poison | ? |
| Halfelin | SRD | Petite | Chanceux (relance les 1 naturels) | ? |
| Gnome | SRD | Petite | Avantage aux sauvegardes mentales contre la magie | ? |
| Demi-orc | SRD | Moyenne | Endurance acharnée (1 PV au lieu de 0, une fois) | ? |
| Demi-elfe | SRD | Moyenne | Polyvalence (compétences en plus) | ? |
| Drakéide | SRD | Moyenne | Souffle et résistance selon l'ascendance | ? |
| Tieffelin | SRD | Moyenne | Résistance au feu | ? |
| … | | | | |
