# Système de jeu — réserves de d10 à succès

> Fiche de règles du jeu (décision du 2026-10-13, inspirée du système d'Aetherpunk). Elle remplace le d20 de D&D
> partout : tests d'événements, actions sociales, fabrication, combat. Les réglages chiffrés sont dans
> `claude_rpg/data/rules.json` (rubriques `dice` et `combat`) ; le code dans `scripts/events/dice.gd` et
> `scripts/combat/combat.gd`.

## Le jet

- On lance **N d10** et on les compare à un **seuil** (le plus souvent la valeur d'un attribut).
- Chaque dé **inférieur ou égal au seuil** est un **succès**.
- Un **9** ou un **10** ne donne jamais de succès.
- Un **1** est toujours un succès, et il est **relancé** : il peut redonner un succès, ou un autre 1 relancé à son
  tour.
- Si le nombre de succès **atteint la difficulté**, le jet est réussi. Les succès au-delà sont des **succès
  supplémentaires**.
- Une action très facile ne demande pas de jet (ouvrir une porte, marcher tranquillement).

## Jet de compétence

- On lance **[rang de la compétence] d10** contre un seuil égal à **l'attribut** utilisé.
- Le jeu prend le meilleur attribut de la compétence, sauf si le test en impose un (option : le choisir soi-même).

## Difficultés

- **1** : une situation de tous les jours qui demande un peu d'attention.
- **2** : une difficulté moyenne pour cette compétence.
- **3** : une action difficile, presque impossible pour un non-professionnel.
- **4** : demande une grande concentration, même pour un expert.
- **5** : une action très difficile, qu'on ne devrait pas rencontrer tous les jours.
- **6** : demande un grand talent et une certaine chance.
- **7** : pratiquement impossible pour la plupart des gens.
- **8 et plus** : digne d'un héros de légende.

## Bonus et malus

- En général, un bonus ou un malus **modifie la difficulté** (avantage : −1, désavantage : +1).
- Sinon, il **ajoute ou retire des dés**.
- Si un malus devait faire tomber le jet à 0 dé, on lance quand même **1 dé** et c'est le **seuil qui baisse**
  d'autant.
- **Attribut au-dessus de 8** : chaque point au-delà de 8 donne un dé de plus, au seuil 8. Exemple : Force 10 et
  Physique 3 → 5 dés au seuil 8.
- **Règle des dés nombreux** (option dans les réglages) : à partir de 10 dés, on retire 10 dés et on gagne
  **seuil + 1 succès** automatiques, autant de fois que possible.

## Critiques

- **Réussite critique N** : N × 3 succès supplémentaires (3 → critique 1, 6 → critique 2, 9 → critique 3).
  Réglage : `rules.json › dice › critical_step`.
- **Échec critique** : aucun succès **et au moins un 10** (décision du 2026-10-13 ; environ 10 % pour un débutant,
  4 % pour un expert). Réglage : `fumble_needs_ten`.
- Leurs effets dépendent de la situation. En combat, une attaque critique permet de relancer les dés de dégâts
  ratés (voir plus bas). Dans un événement, un choix peut prévoir une issue `critical_success` ou
  `critical_failure` (sinon, c'est la réussite ou l'échec ordinaire).

## Opposition

- La difficulté est le **nombre de succès de l'adversaire**.
- **Égalité** : la situation n'évolue pas. Pour imposer un effet (sort, intimidation, test social contre un PNJ), il
  faut donc plus de succès que lui.

## Probabilités (au moins tant de succès)

| Seuil | 1 dé | 2 dés | 3 dés | 4 dés | 5 dés |
|---|---|---|---|---|---|
| 4 (personne ordinaire) | 40 / 4 / 0 % | 64 / 21 / 4 % | 78 / 40 / 12 % | 87 / 56 / 25 % | 92 / 69 / 39 % |
| 5 | 50 / 5 / 1 % | 75 / 30 / 5 % | 88 / 54 / 20 % | 94 / 71 / 39 % | 97 / 83 / 56 % |
| 6 | 60 / 6 / 1 % | 84 / 41 / 7 % | 94 / 68 / 30 % | 97 / 84 / 54 % | 99 / 92 / 73 % |
| 7 | 70 / 7 / 1 % | 91 / 53 / 10 % | 97 / 80 / 43 % | 99 / 92 / 70 % | 100 / 97 / 86 % |
| 8 | 80 / 8 / 1 % | 96 / 67 / 12 % | 99 / 91 / 59 % | 100 / 98 / 85 % | 100 / 99 / 95 % |

Chaque case donne la chance d'obtenir au moins 1, 2 et 3 succès. En jeu, chaque choix avec un test affiche sa
chance de réussite (calculée exactement).

---

## Attributs

- De **3 à 8** pour un humain ; une personne ordinaire a **4** partout. Maximum : 10 (`max_ability_score`).
- **Création** : chaque attribut part de 3 ; 10 points à répartir (coût total : 4 → 1, 5 → 2, 6 → 4), 6 au plus
  avant les bonus ; puis deux bonus de +1 sur des attributs différents. Modèle par classe : 6, 5, 5, 4, 4, 3.
- Améliorations : +1 à un attribut tous les 4 niveaux (comme avant).
- **Vieillesse** : passé l'âge limite, chaque année a 40 % de chances de retirer 1 point (`aging_chance`).

## Résister (ex-jets de sauvegarde)

- Résister à un effet (poison, sort, peur…) est un jet de **compétence** contre l'attribut concerné :
  - FOR, DEX, CON → **Physique** ;
  - SAG → **Perspicacité** ; INT → **Érudition** ; CHA → **Persuasion** (`rules.json › dice › resist_skills`).
- +1 dé si la classe de départ maîtrise cette sauvegarde, +1 par don Résistant, +1 par objet de protection.
- Contre un **sort qui impose un état** (Sommeil) : opposition entre la Magie du lanceur et la résistance de la
  cible ; contre des **dégâts** (Mains brûlantes, Boule de feu) : chaque succès de résistance retire un point.
- C'est l'option B de [jets_de_sauvegarde.md](jets_de_sauvegarde.md), mise en place à titre provisoire.

## Points de vie

- Inchangés dans leur principe : **Constitution × 1,414^taille** (humain CON 6 → 6 PV ; nain CON 6 → 4 PV).
- Les dégâts sont à la même échelle : un coup fait le plus souvent 1 à 3 points.

---

## Combat

### Initiative

- **Initiative de base** = Dextérité + Intelligence (+ rang de Physique avec Vigilant), moins l'encombrement.
- En début de combat : **1d10 + initiative de base**, tous les dés lancés ensemble.
- Égalité : la plus haute Dextérité joue d'abord, puis la plus haute Intelligence, puis au hasard.

### Actions et réactions

- **Deux actions par tour** (rarement plus pour certaines créatures : `actions_per_turn`).
- Chaque action **non utilisée** pendant son tour donne une **réaction défensive** jusqu'à son tour suivant.
- S'il reste des réactions au début de son tour, on les perd et on devient **Préparé** : +2 dés au prochain jet
  de combat (attaque, esquive, parade).
- On peut aussi dépenser une action pour **Se préparer**.
- La Fougue donne une action de plus ; la Ruse permet de Se cacher sans dépenser d'action (une fois par tour) ;
  Mains lestes : utiliser un objet ne coûte pas d'action.

### Attaque

- **[Rang de la compétence de l'arme] d10** contre l'attribut d'attaque (FOR ; finesse : le meilleur de FOR et DEX ;
  à distance : DEX ; sort : Magie contre l'attribut d'incantation).
- **Mêlée** : la difficulté est l'**Esquive naturelle** de la cible = **Dextérité ÷ 3**, arrondie à l'inférieur,
  au moins 1 (DEX 1 à 5 : 1 ; 6 à 8 : 2 ; 9 : 3).
- **Distance** (arcs, sorts) : la difficulté est le **Couvert** de la cible : 1 par défaut, jamais moins ;
  - −1 si sa taille est ≥ 2, −1 encore si ≥ 4, −1 si elle est immobile ;
  - +1 si sa taille est ≤ −2, +1 encore si ≤ −4, +1 si elle est cachée (derrière un muret, un objet ; état
    Invisible), +1 dans la pénombre, +2 dans le noir (le combat d'un événement peut indiquer `"light"`), +1 si elle
    est en mouvement.
- Les états modifient la difficulté (À terre, Entravé : −1 pour qui l'attaque ; Aveuglé, Effrayé : +1 à ses
  attaques).

### Réactions défensives

- **Esquive** : après une attaque réussie, avant les dégâts. Jet de Physique (DEX) ; chaque succès retire un succès
  à l'attaque (une attaque critique peut redevenir normale, une attaque réussie peut rater).
- **Parade** : quand on va subir des dégâts d'une attaque. Jet d'Armes de mêlée (DEX) avec une arme ou un bouclier,
  de Physique (DEX) à mains nues ; certaines armes peuvent imposer un autre seuil (`"parry"`). Chaque succès retire
  un point de dégâts.
  - Une attaque à distance ne se pare qu'avec un bouclier.
  - Une parade par tour, ou une par main avec une arme (ou un bouclier) dans chaque main.
  - On ne pare pas à mains nues une attaque armée (les crocs et les griffes ne sont pas des armes).
  - On peut parer après une esquive qui n'a pas suffi.
- **Contre-attaque** : avant le jet de l'attaquant. L'Esquive naturelle tombe à 0 pour les deux ; les deux font un
  jet d'attaque en opposition ; le plus de succès touche (égalité : l'attaquant initial), avec un critique selon
  l'écart ; le perdant ne peut ni esquiver ni parer cette attaque. Contre un tir, il faut soi-même une arme de tir
  (le Couvert tombe alors à 0).
- **Qui choisit** : le joueur, pour ses personnages, sauf ceux joués par l'IA. Pendant le tour ennemi, le jeu
  s'arrête à chaque occasion (« Contre-attaquer / Laisser venir », « Esquiver / Ne pas esquiver », « Parer /
  Encaisser ») et montre les dés de chacun. Les créatures et les personnages en mode IA réagissent seuls.

### Dégâts et Armure

- **[Rang de la compétence de l'arme] d10** contre le **seuil de l'arme** : chaque succès est un point de dégâts.
  - Seuil : celui de l'attaque (FOR, ou DEX pour une arme de finesse) ; ou un seuil fixe (arc court 5, arc long 6).
  - Les **armes plus grosses donnent des dés en plus** (décision du 2026-10-13) : dague, gourdin −1 ; épée courte,
    masse, bâton +0 ; rapière, épée longue +1 ; hache à deux mains +2 ; mains nues −1 ; polyvalente à deux mains
    +1. Une arme magique +1 donne un dé d'attaque et un dé de dégâts ; le style Duel, un dé de dégâts.
  - Exemple : guerrier FOR 7, épée longue à deux mains (+2 dés), Armes de mêlée 2 → 4d10 contre 7.
- L'**Armure** de la cible (armure portée + bouclier + objets) **baisse le seuil** des dégâts d'autant, sans passer
  sous 1 (décision du 2026-10-13) : au seuil 1, seuls les 1 font des dégâts, si bien qu'une marée de rats finit
  quand même par blesser un chevalier en harnois. Vêtements 0, armures légères 1, intermédiaires 1 ou 2, cotte de mailles 3, harnois 4, bouclier +1.
- **Critique N** : on peut relancer jusqu'à N fois les dés de dégâts en échec. Un dé relancé qui fait 1 se relance
  comme d'habitude ; un dé né d'un 1 ne se relance pas grâce au critique.
- **Attaque surprise** (la cible ignore votre présence : vous êtes caché, ou elle dort, ou elle est paralysée) :
  - Esquive naturelle à 1 (le Couvert ne change pas) ;
  - pas de réaction possible ;
  - l'armure est ignorée, sauf une armure naturelle ;
  - critique 1 dès 1 succès supplémentaire (2 dès 4, 3 dès 7).

### Autres règles de combat

- **Fuite** : Physique (DEX) contre la difficulté de fuite (2 par défaut, `flee_difficulty`).
- **Sorts** : attaque de sort contre le Couvert ; dégâts = rang de Magie (+ dés du sort) contre l'attribut
  d'incantation + bonus ; les sorts de zone se résistent (DEX : chaque succès retire un point).
- **Paliers** : les tours de magie gagnent un dé de dégâts aux niveaux 5, 11 et 17 ; l'Attaque sournoise ajoute un
  dé de dégâts par palier (1 au niveau 1, 6 au niveau 11).
- **États** : Poison (1 dégât par tour, les charges sont la durée), Affaibli (un dé de dégâts de moins par charge),
  Protection (chaque charge absorbe 1 point), Endormi et Paralysé (pris par surprise), Invisible (caché : ses
  attaques sont des surprises, Couvert +1), Préparé (+2 dés).

---

## Hors combat

- **Événements** : `"check": {"skill": "physique", "ability"?: "dex", "difficulty": 2}` ; un test d'attribut seul
  (`{"ability": "dex", "difficulty": 1}`) lance 2 dés ; résister : `{"resist": "con", "difficulty": 1}`.
- **Actions sociales** : contre une difficulté (+ l'humeur et les traits du PNJ : radieux −1, maussade +1,
  furieux +2), ou en opposition contre une compétence du PNJ (ses traits et son humeur lui ajoutent des dés). Un dé
  de moins sans langue commune.
- **Perspicacité passive** (et autres valeurs passives) : le nombre moyen de succès de la réserve, arrondi.
- **Fabrication** : Artisanat (DEX) à la forge, Potions et cuisine à l'alchimie, contre la difficulté de la recette
  (1 par défaut).
- **Prix** : la remise vaut 5 % par succès moyen de la Persuasion du meilleur négociateur, au plus 15 %.
- **Talent fiable** (Roublard) : un test d'une compétence entraînée a toujours au moins un succès.

---

## Choix faits en l'absence de précision (à valider)

1. **Préparé (+2)** : deux dés de plus, au prochain jet de combat (attaque, esquive ou parade).
2. **Avantage et désavantage** (états, événements) : difficulté −1 / +1 ; pour un jet sans difficulté (dégâts,
   résistance), un dé de plus ou de moins.
3. **Réactions automatiques** (créatures, personnages en mode IA) : contre-attaquer si l'on a nettement plus de
   chances de l'emporter, esquiver dès qu'une attaque touche, puis parer. Les ennemis gardent parfois une action
   pour se défendre (25 %).
4. **Sorts** : leurs dégâts gardent un bonus de seuil (Trait de feu : seuil INT +2) ; seules les armes et les
   attaques des créatures sont passées aux dés en plus.
5. **Créatures** : attributs convertis (÷ 2,5) ; PV calculés comme ceux des personnages (sauf l'Alpha : 12) ;
   l'Alpha a une armure naturelle de 1, le brigand une armure de cuir (1).
6. **Échelles converties** : anciens DD → difficulté (11 et moins → 1, 12-14 → 2, 15-17 → 3, 18-20 → 4) ; dégâts
   et soins des événements ÷ 2,5 ; Force des armures 4 / 5 / 6 ; capacité de charge 18 kg par point de Force ;
   encombrement −1 dé par point de Force manquant (au plus −3).
7. **Dons** : Robuste +3 PV ; Archerie +1 dé ; Duel +1 dé de dégâts ; Défense +1 Armure ; Armes à deux mains : une
   relance des dés de dégâts ratés ; Critique amélioré : un succès supplémentaire compté en plus ; Évocation
   renforcée : un dé de dégâts ; Dérobade : chaque succès de résistance (DEX) en retire deux ; Inflexible : relance
   une résistance ratée ; Vigilant : rang de Physique à l'initiative ; Esquive instinctive : dégâts divisés par deux.
8. **Croc-en-jambe du loup** : il met À terre au lieu d'étourdir.

## Questions

1. **Améliorations d'attribut** : sur l'échelle 3-8, +1 pèse lourd. Elles arrivent :
   - tous les 4 niveaux de classe (4, 8, 12, 16, 20) : +1 à un attribut **et** un don au choix ;
   - par certains dons : « Amélioration d'attribut » (+1 à deux attributs, ou +2 au même), et les demi-dons
     (Athlète, Résistant, Érudit des arcanes…) qui donnent +1 à un attribut en plus de leur effet ;
   - par le don du passé, dès la création (ex. Érudit des arcanes : +1 INT).
   Un guerrier peut ainsi passer de FOR 7 à 10 au niveau 4 (+1, puis +2 avec le don). Faut-il limiter (+1 par
   palier seulement, don d'amélioration à +1, plafond plus bas) ?
2. **Test d'attribut sans compétence** : 2 dés contre l'attribut, ça te va ?
