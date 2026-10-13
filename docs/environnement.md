# Environnement et terrain — Lifantasy

> Document de réflexion : pistes et options pour que le lieu, la météo et le terrain comptent, en combat comme
> hors combat. Le combat n'a pas de positionnement : il faut donc des solutions sans grille.

## Ce qui existe aujourd'hui

- Des **lieux** (Brumeval, Forêt des Murmures, chez soi) avec leurs événements, leurs PNJ et leur repos (auberge,
  camp, maison).
- Des **moments de la journée** (matin, après-midi, soir), visibles dans les décors.
- En combat : des **états** (Aveuglé, À terre, Entravé…) qui donnent avantage ou désavantage.
- Rien ne dépend encore du terrain ni de la météo.

---

## Piste 1 — Des états de terrain posés par l'événement

- Le combat déclaré par un événement porte un **terrain** : `"terrain": ["fog", "mud"]`.
- Chaque terrain applique des états à tous, ou à un camp, au début du combat ou de chaque round :
  - **Brouillard** : tout le monde Aveuglé 1 au premier round ;
  - **Boue** : désavantage aux tests de Physique, fuite plus difficile ;
  - **Obscurité** : désavantage aux attaques à distance (sauf vision dans le noir) ;
  - **Hauteur** : un camp a l'avantage au premier round (embuscade).
- **Pour** : simple, data-driven, réutilise les états existants.
- **Contre** : statique pendant le combat.

## Piste 2 — Des surfaces à la BG3 (sans positionnement)

- Des **surfaces** couvrent tout le champ de bataille ou un camp : huile, eau, glace, toile d'araignée.
- Les types de dégâts interagissent avec elles :
  - feu sur huile → la surface s'embrase (Brûlure pour tous) ;
  - froid sur eau → glace (À terre au hasard) ;
  - foudre sur eau → Étourdi.
- **Pour** : rejoint l'idée de réactions élémentaires (types de dégâts) ; tactique sans grille.
- **Contre** : plus complexe à lire et à équilibrer.

## Piste 3 — La météo du jour

- Chaque jour a une météo (soleil, pluie, brouillard, neige, orage), visible au hub.
- Elle modifie les événements tirés (conditions), les tests de voyage (Survie), et pose un terrain en combat.
- **Pour** : donne de la vie au monde et au temps long (saisons).
- **Contre** : à doser pour ne pas devenir aléatoire et frustrant.

## Piste 4 — Des zones à l'intérieur des lieux

- Un lieu contient des **zones** (la clairière, le ruisseau, la grotte) découvertes par des événements, chacune
  avec ses événements, ses ressources (récolte) et son terrain.
- **Pour** : enrichit l'exploration et la récolte de matériaux.
- **Contre** : demande beaucoup de contenu.

## Piste 5 — Des pièges et dangers hors combat

- Des événements de danger (éboulement, chute, gaz, piège) résolus par un test (Perception passive pour le voir
  venir, Physique pour l'éviter), avec des dégâts et des états.
- **Pour** : immédiat à ajouter avec le système d'événements.
- **Contre** : rien de particulier ; à mêler aux autres pistes.

---

## Questions

1. Quelles pistes retiens-tu (plusieurs peuvent coexister) ?
2. La météo et les saisons doivent-elles exister (avec le temps long) ?
3. Les surfaces élémentaires (piste 2) : liées à la décision sur les types de dégâts ?
4. Le terrain doit-il favoriser un camp (embuscade, hauteur) ?
