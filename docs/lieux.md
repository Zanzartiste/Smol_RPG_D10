# Les lieux — Lifantasy

> Fiche de lore et de conception : les lieux qui doivent exister dans le jeu (`claude_rpg/data/locations.json`), avec
> leurs habitants, leurs services et leur ambiance. Les noms actuels sont provisoires.

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`)

- **Type** : ville, village, zone sauvage, donjon, maison…
- **Région** :
- **Description** : une ou deux phrases d'ambiance.
- **Habitants notables** : (PNJ fixes)
- **Gens qu'on peut y chercher** : (gardes, villageois, bûcherons…)
- **Services** : boutiques, forge, auberge, temple…
- **Repos** : auberge (prix), camp (risques), maison…
- **Dangers** : créatures, pièges, météo…
- **Langues parlées** :
- **Relié à** : (trajets, durées, moyens de transport)
- **Événements et quêtes** :
```

---

## Lieux actuels

### Brumeval (`town`)

- **Type** : bourg.
- **Description** : le bourg, son marché et sa taverne.
- **Habitants notables** : Hilde (forgeronne naine), Gorvald (armurier), Maëlle (herboriste elfe), l'aubergiste.
- **Gens qu'on peut y chercher** : gardes, villageois.
- **Services** : Armurerie de Gorvald, Herboristerie de Maëlle, Forge de Brumeval.
- **Repos** : nuit à l'auberge (5 po).
- **Langues parlées** : Commun (quelques étrangers de passage).

### Forêt des Murmures (`forest`)

- **Type** : zone sauvage.
- **Description** : des bois profonds où rôdent loups et secrets.
- **Gens qu'on peut y chercher** : bûcherons.
- **Repos** : camper (25 % de nuit agitée).
- **Dangers** : loups, l'Alpha des loups, rats géants, brigands.

### Chez soi (`home`)

- **Type** : maison.
- **Description** : se reposer et panser ses plaies.
- **Repos** : dormir chez soi (gratuit).

---

## Lieux candidats (à compléter)

### Une mine

- **Pistes** : récolte de minerai (Artisanat, Physique), éboulements, créatures souterraines, nains.

### Un temple

- **Pistes** : soins, résurrection (revenir à la vie), religion, Clercs.

### Une ville lointaine

- **Pistes** : la quitter pour toujours, autres langues, autres factions (voyages).

---

## Questions

1. Combien de lieux pour la première région, et lesquels ?
2. Faut-il une **carte** (même simple) pour choisir sa destination, ou des voyages purement par événements ?
3. **Revenir à la vie** : dans un temple, par un rituel, grâce à des compagnons, à quel prix ?
4. Les lieux évoluent-ils (une boutique ferme, un quartier brûle) avec le monde autonome ?
