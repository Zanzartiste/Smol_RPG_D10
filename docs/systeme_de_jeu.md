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
- Si le nombre de succès **atteint la difficulté**, le jet est réussi. Les succès au-delà sont des **succès supplémentaires**.
- Une action très facile ne demande pas de jet (ouvrir une porte, marcher tranquillement).

## Jet de compétence

- On lance **[rang de la compétence] d10** contre un seuil égal à **l'attribut** utilisé.
- Le jeu prend le meilleur attribut automatiquement si plusieurs sont autorisés, sauf si une option dans le menu est cochée, permettant de choisir un attribut plus faible si souhaité.

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

- En général, plutôt que d'appliquer un bonus ou malus, on modifie la difficulté du jet.
- Sinon, s'il est précisé qu'il y a bien un malus/bonus, on **ajoute ou retire des dés**.
- Si un malus devait faire tomber le jet à 0 dé, on lance quand même **1 dé** et c'est le **seuil qui baisse** d'autant.
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

- De **3 à 8** pour un humain en règle générale ; une personne ordinaire a **4** partout. Pas de maximum.
- **Création** (décision du 2026-10-14) : chaque attribut part de 3, quelles que soient l'espèce et la classe ;
  9 points à répartir (1 point = +1), 6 au plus ; tous les points doivent être dépensés. Pas de bonus. Modèle
  suggéré par classe : 6, 5, 5, 4, 4, 3.
- Améliorations : +1 à un attribut aux niveaux 5, 10, 15 et 20 (`rules.json › advancement`). Aucun don ne donne
  d'attribut.
- **Vieillesse** : passé l'âge limite, chaque année a 40 % de chances de retirer 1 point (`aging_chance`).

## Résister (ex-jets de sauvegarde)
- Résister à un effet (poison, sort, peur…) est un simple jet de **compétence**, sans maîtrise de classe : chaque
  effet ou altération demande sa compétence, le plus souvent **Physique** pour les effets physiques (poison,
  brûlure, croc-en-jambe…) et **Détermination** pour les effets mentaux (peur, sommeil, charme…).
- *Technique, provisoire* : les données indiquent encore un attribut (`"resist": {"ability": "dex"}`), traduit en
  compétence par `rules.json › dice › resist_skills` (FOR, DEX, CON → Physique ; SAG → Détermination ;
  INT → Érudition ; CHA → Persuasion) ; le seuil est cet attribut.
- +1 dé par don Résistant, +1 par objet de protection.
- Contre un **sort qui impose un état** (Sommeil) : opposition entre la compétence d'incantation du lanceur et la résistance de la
  cible ; contre des **dégâts** (Mains brûlantes, Boule de feu) : chaque succès de résistance retire un point.
- C'est l'option B de [jets_de_sauvegarde.md](jets_de_sauvegarde.md), mise en place à titre provisoire.

## Points de vie

- **(Taille + 2) × CON + 7**, au moins 1 (décision du 2026-10-14 ; `rules.json › hit_points`). Humain moyen (taille
  0, CON 4) : 15 PV ; humain CON 6 : 19 PV ; nain (taille −1) CON 6 : 13 PV ; un grand colosse dépasse 40 PV.
- Fourchette visée : de 1 à 55 PV selon la Constitution et la taille.
- Certains dons modifieront les PV (Robuste). Pas de progression des PV par niveau pour l'instant.
- Les dégâts sont à la même échelle : un coup fait le plus souvent 2 à 5 points.

## Compétences à la création

- Rang de départ : 2 pour une compétence instinctive, 1 pour les autres.
- Le **passé** donne 4 rangs (1 par compétence), la **classe** 8 (2 au plus par compétence) (tableur `Classes.ods`, voir [classes.md](classes.md)).
- Puis **8 rangs libres** ; tous doivent être répartis. Une répartition suggérée par la classe est proposée.
- **Plafond** : aucune compétence ne dépasse 5 à la création, rang de départ, passé et classe compris ; un rang
  au-delà revient aux rangs libres.
- Au total, environ 20 rangs répartis (4 + 8 + 8).

## Points de compétence

- Tous les deux niveaux, aux niveaux 2, 4, 6… 20 (`rules.json › skill_points › by_level`, réglable niveau par
  niveau), le personnage gagne 1 point de compétence à dépenser à la montée de niveau : chaque point monte d'un rang une compétence.
- Après la création, pas de plafond : chaque point fait monter une compétence d'un rang, et une même compétence
  ne monte que d'un rang par niveau au plus (décision du 2026-10-14 ; `Character.level_raises`).

---

## Combat

### Initiative

- **Initiative de base** = Dextérité + Intelligence, moins l'encombrement.
- En début de combat : **1d10 + initiative de base**, tous les dés lancés ensemble.
- Égalité : la plus haute Dextérité joue d'abord, puis la plus haute Intelligence, puis au hasard.

### Actions et réactions

- **Deux actions par tour** (rarement plus pour certaines créatures : `actions_per_turn`).
- Chaque action **non utilisée** pendant son tour donne une **réaction défensive** jusqu'à son tour suivant.
- S'il reste des réactions au début de son tour, on les perd et on devient **Préparé** : +2 dés au prochain jet
  de combat (attaque, esquive, parade, sort...).
- On peut aussi dépenser une action pour **Se préparer**.
- La Fougue donne une action de plus ; la Ruse permet de Se cacher sans dépenser d'action (une fois par tour) ;
  Mains lestes : utiliser un objet ne coûte pas d'action.

### Attaque

- **[Rang de la compétence de l'arme] d10** contre l'attribut d'attaque (FOR ; finesse : le meilleur de FOR et DEX ;
  à distance : DEX ; sort : compétence d'incantation contre l'attribut d'incantation).
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
- **Contresort** : quand un ennemi lance un sort, un lanceur de sorts peut le contrer, avant de savoir si le sort
  touchera : opposition des compétences d'incantation ; s'il a plus de succès, le sort est annulé (l'action est perdue).
  Il dépense sa réaction.
- **Réactions automatiques** (option de l'écran titre) : tout le groupe réagit seul, comme l'IA.
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
- **Moral des ennemis** (`creatures.json › morale`) :
  - lâche : sous 30 % de ses PV, il peut prendre la fuite (une chance sur deux par tour) ;
  - meute : elle peut fuir quand son chef (`leader`) tombe, ou quand la moitié des siens est hors de combat ;
  - sans peur : se bat jusqu'au bout.
  Une créature enfuie ne rapporte ni XP ni butin.
- **IA des ennemis** : les chasseurs (`"ai": "hunter"`) visent le plus faible, les brutes frappent au hasard.
  Soigner ne sert que si un allié est sous 50 % de ses PV, protéger que sous 75 % ; ces actions deviennent alors
  prioritaires et visent l'allié le plus mal en point (`ai_heal_below`, `ai_protect_below`, `ai_support_bonus`).
- **Météo** : brouillard et orage plongent les combats en plein air dans la pénombre (Couvert +1).
- **Compétence d'incantation** : arcanique → Érudition (Magicien), divine → Détermination, primale → Nature,
  artistique → Arts ; Initié à la magie : magicien → Érudition, clerc → Détermination, druide → Nature.
- **Mana** : réserve = niveau de lanceur × 2 (demi-lanceur : moitié de ses niveaux) ; un sort de niveau N coûte
  N mana, les tours de magie rien. Le mana manquant se paie en PV (1 pour 1), jusqu'à 0 PV (on tombe). L'IA ne
  puise jamais dans ses PV. Repos long : tout le mana revient.
- **Dons « 1/jour »** (Costaud, Malin, Agile…) : après un test raté sous l'attribut du don, un dé de plus est lancé
  d'office (on a vu le résultat) ; Chanceux transforme un échec critique en échec. Recharge au repos long.
- **Sorts** : attaque de sort contre le Couvert ; dégâts = rang de la compétence d'incantation (+ dés du sort) contre l'attribut
  d'incantation + bonus ; les sorts de zone se résistent (DEX : chaque succès retire un point).
- **Paliers** : les tours de magie gagnent un dé de dégâts aux niveaux 5, 11 et 17 ; l'Attaque sournoise ajoute un
  dé de dégâts par palier (1 au niveau 1, 6 au niveau 11).
- **Emplacements de sort** (décision du 2026-10-14) : une seule réserve d'emplacements « de niveau 1 » ; lancer un
  sort de niveau N coûte N emplacements. La réserve vaut la table du SRD pondérée par le niveau des sorts (magicien :
  2 au niveau 1, 8 au niveau 3, 16 au niveau 5) ; la table fixe aussi le niveau de sort le plus haut lançable.
- **Sorts connus et équipés** : un lanceur connaît les sorts de sa classe, mais seuls les sorts **équipés** sont
  utilisables en combat : 2 + rang de la compétence d'incantation (5 pour un magicien débutant sans rang libre). Les **tours de magie** sont toujours
  prêts, en plus de cette limite (décision du 2026-10-14). Un sort appris est équipé d'office s'il reste de la place.
  On les change hors combat, dans l'onglet Sorts du tiroir.
- **États** : Poison (1 dégât par tour, les charges sont la durée), Affaibli (un dé de dégâts de moins par charge),
  Protection (chaque charge absorbe 1 point), Endormi et Paralysé (pris par surprise), Invisible (caché : ses
  attaques sont des surprises, Couvert +1), Préparé (+2 dés), Enragé (Rage du Barbare : corps à corps seulement,
  succès des attaques doublés dans les deux sens).
- **Critiques** : Attaques précises (Roublard) ajoute 3 dés de dégâts à une attaque critique.
- **Deux armes** (pour tous) : une arme de corps à corps à une main peut se tenir en main secondaire (bouton « Main
  secondaire » de l'inventaire). Chaque attaque de l'arme principale est alors suivie d'une attaque de la main
  secondaire, avec ses propres jets, à deux dés de moins à l'attaque et aux dégâts (`combat › off_hand_penalty`) ;
  le style À deux armes retire ce malus.
- **Parchemins** : objets à usage unique qui lancent un sort, sans emplacement, avec la compétence Langues (et son
  meilleur attribut) à la place de la compétence d'incantation (`rules.json › scrolls`). Lire un parchemin coûte
  une action et débloque le Magicien pour les vies suivantes.

---

## Hors combat

- **Événements** : `"check": {"skill": "physique", "ability"?: "dex", "difficulty": 2}` ; résister :
  `{"resist": "con", "difficulty": 1}`. Pas de test d'attribut seul (règle retirée le 2026-10-15).
- **Actions sociales** : contre une difficulté (+ l'humeur et les traits du PNJ : radieux −1, maussade +1,
  furieux +2), ou en opposition contre une compétence du PNJ (ses traits et son humeur lui ajoutent des dés). Un dé
  de moins sans langue commune.
- **Perspicacité passive** (et autres valeurs passives) : le nombre moyen de succès de la réserve, arrondi.
- **Fabrication** : Artisanat (DEX) à la forge, Alchimie à l'alchimie, contre la difficulté de la recette
  (1 par défaut).
- **Prix** : la remise vaut 5 % par succès moyen de la Persuasion du meilleur négociateur, au plus 15 %.
- **Talent fiable** (Roublard) : un test d'une compétence entraînée a toujours au moins un succès.
- **Récolte** (« Chercher des ressources », lieux sauvages, `locations.json › gather`) : un test par ressource ;
  réussite : la ressource ; critique : le double ; échec critique : une petite blessure.
- **Demandes des PNJ** (« Proposer ses services ») : le PNJ confie une demande de son métier (`npc_roles.json ›
  requests`) qui devient une quête ; « Remettre la commande » rapporte l'or promis et de l'amitié. Une demande à la
  fois par PNJ, trois jours entre deux.

---

## Choix faits en l'absence de précision (à valider)

1. **Préparé (+2)** : deux dés de plus, au prochain jet de combat (attaque, esquive ou parade).
2. **Avantage et désavantage** (états, événements) : difficulté −1 / +1 ; pour un jet sans difficulté (dégâts,
   résistance), un dé de plus ou de moins.
3. **Réactions automatiques** (créatures, personnages en mode IA) : contre-attaquer si l'on a nettement plus de
   chances de l'emporter, esquiver dès qu'une attaque touche, puis parer. Les ennemis gardent parfois une action
   pour se défendre (25 %).
4. **Sorts** : leurs dégâts gardent un bonus de seuil (Trait de feu : seuil INT +2) ; seules les armes et les
   attaques des créatures sont passées aux dés en plus (voir la question 3).
5. **Créatures** : attributs convertis (÷ 2,5) ; PV calculés comme ceux des personnages (sauf l'Alpha : 12) ;
   l'Alpha a une armure naturelle de 1, le brigand une armure de cuir (1).
6. **Échelles converties** : anciens DD → difficulté (11 et moins → 1, 12-14 → 2, 15-17 → 3, 18-20 → 4) ; dégâts
   et soins des événements ÷ 2,5 ; Force des armures 4 / 5 / 6 ; capacité de charge 18 kg par point de Force ;
   encombrement −1 dé par point de Force manquant (au plus −3).
7. **Dons** : Robuste +3 PV ; À distance +1 dé ; À une main +1 dé de dégâts ; Armes à deux mains : une
   relance des dés de dégâts ratés ; Critique amélioré : un succès supplémentaire compté en plus ; Évocation
   renforcée : un dé de dégâts ; Dérobade : chaque succès de résistance (DEX) en retire deux ; Inflexible : relance
   une résistance ratée ; Esquive instinctive : dégâts divisés par deux.
8. **Croc-en-jambe du loup** : il met À terre au lieu d'étourdir.

## Questions

1. **Puissance des sorts** (reformulation de la question 13) : les grosses armes lancent plus de dés (une hache à
   deux mains : +1 dé). Les sorts, eux, rendent leur seuil plus facile : Trait de feu lance autant de dés que le
   rang de Magie, et chaque dé réussit sur INT + 2 au lieu de INT. Faut-il plutôt donner aux sorts des dés en plus,
   comme les armes (Trait de feu : rang de Magie + 1 dé, seuil INT) ? Les dés en plus montent plus haut (plus de
   critiques), le seuil facile rend les dégâts plus réguliers. => Pas vraiment comme ça que je le vois, cf les notes ajoutées à équipements.
