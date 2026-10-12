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
- **Statut** : disponible par défaut.
- **Taille** : Moyenne.
- **Âge de départ** : 18.
- **Adolescent à** : 12.
- **Adulte à** : 18.
- **Âgé à** : 60.
- **Vénérable à** : 80.
- **Vieillit à partir de** : 60.
- **Traits** : Vous obtenez un don supplémentaire au choix (implémenté : le choix s'ouvre au début de la partie).
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

### Nain (`dwarf`)

- **Concept** : petits, robustes et barbus. Mineurs, forgerons et bâtisseurs, ils ont la rancune aussi tenace que la peau.
- **Statut** : disponible.
- **Taille** : Moyenne (trapus plutôt que petits, comme dans le SRD).
- **Âge de départ** : 50.
- **Adolescent à** : 20.
- **Adulte à** : 50.
- **Âgé à** : 250.
- **Vénérable à** : 330.
- **Vieillit à partir de** : 250.
- **Traits** : résistance au poison (implémentée).
- **Traits possibles plus tard** : vision dans le noir, avantage aux sauvegardes contre le poison (il faudra le
  système d'avantage), bonus en forge ou en connaissance de la pierre.
- **Noms** : Thorgrim, Dagna, Brakka, Orsik, Helga, Durnak, Vistra, Kildrak, Runa, Barek. Plus tard : un nom de clan.
- **Apparence** : peau claire à bronzée, cheveux bruns, roux ou gris ; barbe très fréquente (90 %).
- **Descendance** : *à définir.*

### Orc (`orc`)

- **Concept** : grands, puissants et fiers, les orcs vivent intensément et tiennent debout là où d'autres tombent.
- **Statut** : disponible.
- **Taille** : Moyenne.
- **Âge de départ** : 18.
- **Adolescent à** : 12.
- **Adulte à** : 18.
- **Âgé à** : 50.
- **Vénérable à** : 65.
- **Vieillit à partir de** : 50 (vie courte, comme le demi-orc du SRD).
- **Traits** : Endurance implacable : une fois par repos long, l'orc tombe à 1 PV au lieu de 0 (implémentée).
- **Traits possibles plus tard** : vision dans le noir ; Attaques sauvages (critiques plus violents) ; bonus
  d'Intimidation.
- **Noms** : Grosh, Ukra, Murzag, Thokk, Yrsa, Bolgra, Kharn, Shagra, Durza, Rokh.
- **Apparence** : peau verte, olive ou grise ; défenses ; yeux rouges ou ambrés.
- **Descendance** : *à définir* (le SRD prévoit le demi-orc avec un humain).

### Tieffelin (`tiefling`)

- **Concept** : une ascendance infernale marque leur corps de cornes et de flammes ; beaucoup s'en méfient.
- **Statut** : disponible.
- **Taille** : Moyenne.
- **Âge de départ** : 18.
- **Adolescent à** : 12.
- **Adulte à** : 18.
- **Âgé à** : 70.
- **Vénérable à** : 90.
- **Vieillit à partir de** : 70.
- **Traits** : résistance au feu (implémentée).
- **Idée de trait** : (ou dépendant d'un choix basé sur un démon majeur). Piste : une **ascendance** choisie à la
  création, chacune avec sa résistance et un petit sort (feu, froid, nécrotique…). Il faudrait alors un choix
  supplémentaire dans l'écran de création, à l'image des sous-classes.
- **Noms** : Méphara, Ilzac, Vhorn, Saelith, Akzar, Nyx, et des noms de vertu : Espérance, Tourment, Audace, Chant.
- **Apparence** : peau rouge, prune, rosée ou violette ; cornes ; yeux dorés, blancs ou rouges.
- **Descendance** : *à définir* (le sang infernal peut-il ressurgir chez un enfant de parents non tieffelins ?).

---

## Espèces candidates (à compléter)



### Halfelin (SRD)

- **Taille** : Petite.
- **Idée de trait** : Chanceux (relance les 1 naturels).
- **Priorité** : ?

### Gnome (SRD)

- **Taille** : Petite.
- **Idée de trait** : avantage aux sauvegardes mentales contre la magie.
- **Priorité** : ?

### Drakéide (SRD)

- **Taille** : Moyenne.
- **Idée de trait** : souffle et résistance selon l'ascendance draconique.
- **Priorité** : ?


