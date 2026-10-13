# Cahier des charges — Lifantasy (titre provisoire)

> Version 0.7 — 2026-10-13 — document vivant, à mettre à jour au fil des décisions.

---

## 1. Pitch

Un **RPG narratif roguelite piloté par menus**. On crée un personnage (ex. : un gobelin mage), puis on vit sa vie au fil
d'**événements semi-aléatoires** : explorer la forêt, rester en ville, se marier, devenir forgeron, partir à l'aventure
avec des compagnons… Les choix et les combats se jouent **au tour par tour**. Quand le personnage meurt, on en crée un
nouveau dans **le même monde**, qui garde la trace des vies précédentes (lignée, héritage, conséquences, déblocages).

**Références :**
- **Gameplay / UI :** PokeRogue (interface, combats en équipe au tour par tour, runs successives).
- **Narration émergente :** Wildermyth, King of Dragon Pass, Reigns, BitLife.
- **Persistance du monde et lignées :** Crusader Kings, Rogue Legacy (héritage), Dwarf Fortress (les légendes).

## 2. Objectifs du projet

| Élément | Décision |
|---|---|
| Type de projet | Petit jeu **complet**, publiable (ex. itch.io) |
| Équipe | Solo, niveau intermédiaire en Godot |
| Moteur | Godot 4.4, GDScript |
| Plateformes | PC (Windows en priorité) + Web |
| Durée d'une vie (run) | ~20 min en moyenne, mais pouvant durer plusieurs heures |
| Rendu | 2D, interface : panneaux, icônes, portraits, texte |

## 3. Piliers de design

Ce sont les règles qui servent à trancher quand on hésite sur une fonctionnalité.

1. **Chaque vie raconte une histoire** : les événements et les choix priment sur la mécanique pure.
2. **Le monde se souvient** : ce qu'ont fait les personnages précédents a des conséquences visibles.
3. **Liberté de vie** : partir à l'aventure n'est pas obligatoire. On peut s'installer, travailler, fonder une famille.
4. **Tout est dans les données** : les événements, espèces, classes et objets sont décrits dans des fichiers de données, pas
   codés en dur, pour pouvoir ajouter du contenu sans toucher au code.

## 4. Boucle de jeu

```
┌──────────────────────────────────────────────────────────────────┐
│  MÉTA (entre deux vies)                                          │
│  Création du perso → espèce, classe, passé, lien avec la lignée  │
│  Achats permanents (monnaie méta), choix d'héritage              │
└───────────────┬──────────────────────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────────────────┐
│  VIE (la run)                                                    │
│  1. Choisir un lieu / une activité (forêt, ville, taverne…)      │
│  2. Un événement est tiré dans le pool éligible                  │
│  3. Choix → effets (stats, objets, relations, flags, combat…)    │
│  4. Le temps passe (âge, saisons ?) → retour en 1                │
└───────────────┬──────────────────────────────────────────────────┘
                ▼  mort (combat, vieillesse, événement…)
┌──────────────────────────────────────────────────────────────────┐
│  BILAN : récit de la vie, haut-faits, déblocages, impact monde   │
└───────────────┬──────────────────────────────────────────────────┘
                └──────────► retour à MÉTA
```

## 5. Fonctionnalités : vision complète

### 5.1 Personnage
- **Espèce** (gobelin, humain, elfe…), **passé** et **classe/métier** (mage, guerrier, forgeron…), dont certains se débloquent.
- **Statistiques** inspirées de D&D 5e : 6 attributs, compétences, dons (voir §9).
- **Traits** (courageux, avare, maladroit…) qui influencent les événements et les choix proposés.
- **Compétences / sorts** utilisés en combat.
- **Âge** : le personnage vieillit, et la vieillesse peut mettre fin à sa vie.
- **Portrait** (assemblé à partir de calques ou choisi dans une liste).

### 5.2 Événements (cœur du jeu)
- Un **pool d'événements par lieu/activité** (forêt, ville, mine, taverne, domicile…).
- Chaque événement possède :
  - des **conditions d'apparition** : flags, stats, espèce, taille, passé, genre, classe, relation, objets possédés, événements déjà vus, état du
    monde, âge…
  - un **poids** (probabilité relative) et éventuellement une rareté ou une limite (unique, répétable…) ;
  - un **texte** et une illustration ou icône ;
  - des **choix**, avec leurs propres conditions (ex. option visible seulement si Intelligence ≥ 5) et parfois un
    **test de stat** (réussite ou échec) ;
  - des **effets** : modifier une stat, donner ou retirer un objet, poser un flag, changer une relation, lancer un combat,
    enchaîner sur un autre événement, faire passer du temps, changer l'état du monde, tuer le personnage…
- Les **chaînes d'événements** (quêtes) reposent sur des flags : l'événement A pose `rencontre_marchand`, et l'événement B
  exige ce flag.

### 5.3 Compagnons et relations
- PNJ recrutables : aventuriers, conjoint, enfants, animaux…
- **Relation** chiffrée avec chaque PNJ (affection, confiance…), qui débloque des événements (romance, trahison,
  mariage).
- Les compagnons participent aux combats et ont leurs propres stats et compétences.
- **Événements de groupe** : disputes, discussions au coin du feu, etc.

### 5.4 Combat
- Au tour par tour, l'équipe du joueur affronte un groupe d'ennemis, avec une interface à la PokeRogue.
- Actions : attaquer, utiliser un sort ou une compétence, un objet, fuir.
- Ordre des tours fixé par l'initiative (d20 + modificateur de Dextérité). Pas de positionnement.
- Effets de statut (poison, étourdissement…) et éventuellement des affinités élémentaires.
- Si un compagnon meurt, il meurt pour de bon. Si le héros meurt, la vie se termine.

### 5.5 Vie sédentaire / métiers
- On peut choisir de **s'établir** : travailler (forgeron, marchand…), gagner de l'argent, acheter une maison…
- Des événements propres à la vie en ville : commandes, concurrence, impôts, fêtes, rumeurs.

### 5.6 Méta-progression
| Mécanique | Description |
|---|---|
| **Déblocages** | Espèces et classes débloquées par des haut-faits ou des aventures spécifiques |
| **Lignée / héritage** | Le nouveau personnage peut être l'enfant d'un ancien, ou lié à lui autrement, et hériter d'objets, de traits ou d'une maison |
| **Monde persistant** | Des flags « monde » survivent à la mort : une ville détruite, un PNJ mort, une tombe à visiter… |
| **Monnaie méta** | Gagnée à chaque vie, elle sert à acheter des bonus permanents |
| **Chronique** | Historique des vies passées, consultable (« Légendes ») |

### 5.7 Interface
- Écran titre, création de personnage, écran principal (lieu, perso, équipe, journal), écran d'événement, écran de
  combat, inventaire, fiche perso, bilan de mort, chronique.
- Doit rester lisible à la souris sur PC et sur le Web (et pourquoi pas au tactile plus tard).

### 5.8 Sauvegarde
- **Obligatoire en cours de vie**, puisqu'une partie peut durer des heures.
- Une sauvegarde méta (déblocages, monde, lignée), séparée de la sauvegarde de la vie en cours.
- Sur le Web, elle passe par `user://` (stockage IndexedDB du navigateur).

## 6. MVP : première version jouable

> **Note v0.4** : le projet **ne se limite pas au MVP**. Le MVP n'est qu'une première tranche jouable pour les testeurs ;
> le développement continue ensuite par jalons de systèmes (voir §10). La priorité actuelle est de **peaufiner les
> systèmes de jeu**, le lore et l'univers viendront plus tard.

L'objectif du MVP est d'avoir **une boucle complète, de bout en bout**, avec peu de contenu. Le MVP sert à vérifier que
le jeu est amusant avant de produire du contenu en masse.

**Dans le MVP :**
- [x] Création de perso : **2 espèces × 2 classes**, passé, genre, attributs par achat de points, nom.
- [ ] **1 ville + 1 zone sauvage** (forêt).
- [ ] Moteur d'événements data-driven : conditions, choix, effets, flags, tests de stats.
- [ ] **~30 événements**, dont 1 petite chaîne de quête et 1 événement de recrutement de compagnon.
- [x] Combat tour par tour : équipe de **2 maximum** (héros + 1 compagnon), 5 types d'ennemis, 1 boss (l'Alpha).
- [ ] Inventaire simple (consommables et équipement basique).
- [ ] Mort → écran de bilan → nouveau perso.
- [ ] Méta : **1 déblocage** (une espèce ou classe) et **1 flag monde persistant**.
- [ ] Sauvegarde et chargement.
- [ ] Export Windows et Web.
- [ ] Temps (plusieurs actions par jour), âge et vieillissement, y compris la mort de vieillesse.
- [ ] Portraits générés par IA pour les 2 espèces × 3 âges, et quelques illustrations d'événements.

**Hors MVP (pour plus tard) :** mariage et enfants, lignée complète, métiers sédentaires, dons,
portraits modulaires, monnaie méta, chronique, son et musique, équilibrage poussé, traduction anglaise (prévue dans
l'architecture dès le départ, voir §9).

## 7. Contraintes techniques

| Sujet | Décision / recommandation |
|---|---|
| **Renderer** | **Compatibility** (OpenGL), requis pour l'export Web. Forward+ ne fonctionne pas dans un navigateur. |
| Résolution | Base 1280×720 ou 1920×1080, stretch mode `canvas_items`, aspect `expand`. |
| Données de contenu | Événements, espèces, classes, passés, objets, ennemis : fichiers **JSON** dans `res://data/`. |
| Architecture | Autoloads `DB` (données), `Meta` (monde persistant) et `Game` (vie en cours). Logique sans état dans `scripts/events/` (Conditions, Effects, Dice, EventEngine). Scènes d'UI découplées par signaux. Détails dans [modele_donnees.md](modele_donnees.md). |
| Aléatoire | RNG avec **seed** sauvegardée, utile pour reproduire les bugs et éviter de « save-scummer ». |
| Versioning | Git, avec le `.gitignore` Godot déjà présent dans `claude_rpg/`. |
| Assets | Packs libres au départ (itch.io, game-icons.net pour les icônes). Art final à décider. |

## 8. Risques

| Risque | Mitigation |
|---|---|
| **Scope trop large**, le plus gros risque : simulateur de vie, combat, lignées, monde persistant | S'en tenir strictement au MVP, et noter chaque nouvelle idée dans un backlog plutôt que de l'implémenter tout de suite. |
| **Volume de contenu** : un jeu à événements demande des centaines de textes | Format de données confortable à écrire, éventuellement un petit outil d'édition ; générer des variantes de texte. |
| Événements répétitifs sur les longues vies | Poids dynamiques, cooldowns, événements uniques, conditions basées sur l'âge et l'état du monde. |
| Complexité des conditions et des effets | Un système de conditions et d'effets générique et testé, défini une fois pour toutes. |
| Équilibrage combat × événements | Garder des stats peu nombreuses au départ et exposer les valeurs dans les données. |

## 9. Décisions

| Sujet | Décision | Notes / conséquences |
|---|---|---|
| **Titre** | **Lifantasy** (provisoire) | |
| **Format des données** | **JSON** | Godot le lit nativement (`JSON.parse_string`), alors que le YAML demanderait un addon. Un fichier par type de contenu ou par lieu (`data/events/forest.json`, `data/species.json`…). |
| **Univers et ton** | Fantasy **inspirée de D&D** | ⚠️ Licence : le **SRD 5.1** (CC-BY 4.0) est réutilisable librement (attributs, compétences, sorts et monstres qu'il contient). En revanche, il ne faut pas utiliser la marque « D&D », les Royaumes Oubliés ni les créatures absentes du SRD (tyrannoeils, flagelleurs mentaux…). |
| **Statistiques** | Inspirées de D&D 5e | Voir le détail du MVP ci-dessous. |
| **Temps** | **Plusieurs actions par jour**, **une année = 365 jours** | 3 créneaux par jour (matin, après-midi, soir). Pour faire passer le temps, on s'appuie sur les trajets, les voyages et les attentes de durée choisie. |
| **Vieillissement** | **Oui, dès le MVP** | Au-delà de l'âge limite de l'espèce, chaque année retire 1 à un attribut tiré au hasard. Un attribut à 0 tue le personnage. |
| **Vocabulaire** | **Espèce**, pas « race » | Utilisé partout : données, code, interface. |
| **Espèce** | Taille et âges, **aucun effet sur les attributs** | La taille (Petite, Moyenne…) est une variable du personnage, utilisable dans les conditions. |
| **Passé** | Choisi à la création | Il donne 2 compétences maîtrisées (et parfois de l'or ou des objets). Il est utilisable dans les conditions d'événements. |
| **Genre** | Femme, homme ou non-binaire | Aucun effet sur l'apparence ni sur les règles. Il sert aux accords dans les textes, avec la syntaxe `{g:masculin\|féminin\|neutre}`. |
| **Combat** | Tour par tour façon **D&D**, **sans positionnement**, **4 contre 4** au maximum | Une action par tour (action de classe, sort avec emplacements, objet, fuite). Le joueur contrôle le héros et les compagnons, et les invocations jouent seules. Capacité des camps réglable (`rules.json › combat`), invocations comprises. Les sprites suivent la taille : environ 50 % pour une petite créature, 200 % pour une grande. Le système de decks a été essayé puis abandonné (2026-10-12). |
| **Langue** | Français d'abord, **localisation FR/EN prévue** | Les textes d'interface passent par `tr()` dès le départ. Les textes des JSON sont écrits en français ; leurs clés de traduction sont dérivées des ids (ex. `evt.<id>.text`), et un script générera le CSV de traduction le moment venu. |
| **Direction artistique** | Inspirée de **Baldur's Gate 3**, produite par **IA générative** | Images 2D fixes uniquement : portraits, illustrations d'événements, icônes. L'**interface** a l'ambiance BG3 (sombre, bordures dorées, police serif, fonds parchemin). Voir §9.2 pour le pipeline. |

### 9.1 Statistiques retenues pour le MVP (inspirées du SRD 5e)

- **6 attributs** : Force, Dextérité, Constitution, Intelligence, Sagesse, Charisme. Valeurs de 3 à 20, avec un
  modificateur égal à `(valeur − 10) / 2` arrondi à l'inférieur.
- **Valeurs dérivées** : PV, classe d'armure (CA), initiative, bonus de maîtrise selon le niveau.
- **Répartition** : **achat de points façon BG3** (27 points, valeurs de 8 à 15, puis +2 et +1). La classe propose un
  modèle.
- **Compétences** : les **18 compétences** de D&D. La classe et le passé déterminent celles qui sont maîtrisées. Elles
  servent aux tests des événements (d20 + modificateur contre un DD).
- **Dons** : chaque passé accorde un don d'origine. Les événements peuvent aussi en donner (`add_feat`).
- **Améliorations** : tous les 4 niveaux (4, 8, 12, 16, 20), +1 à un attribut au choix (20 au maximum) **et** un don.
  Réglable dans `rules.json › advancement_levels` et `advancement`.
- **Équipement, types de dégâts et défenses** : un catalogue centralisé (`equipment.json`) et les 13 types de dégâts
  du SRD. Résistances, immunités et vulnérabilités sont gérées pour les personnages comme pour les ennemis. Voir
  [modele_donnees.md](modele_donnees.md) › Règles centralisées.
- **Niveaux** : de 1 à **20**, avec les tables d'XP et de maîtrise de D&D 5e.

### 9.2 Pipeline des images (IA générative)

Claude ne génère pas d'images lui-même. Il peut en revanche écrire le **guide de style**, rédiger et maintenir les
**prompts** (un par asset, versionnés dans le dépôt) et intégrer les images dans Godot.

- **Outil de génération** : à choisir. En local, Stable Diffusion XL ou Flux via ComfyUI ou Forge (gratuit, avec un bon
  contrôle et des LoRA) ; en ligne, Midjourney ou équivalent (rapide, mais moins de contrôle).
- **Cohérence visuelle**, le principal défi : un prompt de style commun, préfixé à tous les prompts. Il faut aussi des
  formats fixes (ex. portrait buste, fond sombre neutre, éclairage de côté), une palette fixe, et noter seed et paramètres.
  À terme, un LoRA de style ou des images de référence (img2img, IP-Adapter).
- **Vieillissement** : générer plusieurs variantes d'âge d'un même personnage (enfant, adulte, âgé). L'img2img à partir
  du portrait adulte aide à garder la ressemblance.
- **Formats** : portraits 512×512 ou 768×768 (affichés réduits), illustrations d'événements en 16:9, icônes en 128×128.
  Images en `.webp` ou `.png` dans `res://assets/`.
- **Organisation** : `art/prompts/` pour les prompts (un fichier par asset ou par catégorie) et `art/style_guide.md`
  pour le guide de style.
- **Licence et publication** : vérifier les conditions d'utilisation commerciale de l'outil ou du modèle choisi.
  **Steam exige de déclarer l'usage d'IA générative**, et itch.io propose une mention dédiée.

### 9.3 Décisions de la v0.3 (réponses aux questions du 2026-10-12)

| Sujet | Décision |
|---|---|
| **Sauvegarde** | Méta **et** vie en cours (on peut quitter et reprendre). |
| **Méta-progression** | Des **Creator Points** gagnés à chaque vie, dépensés à la création : meilleures stats, espèce « meilleure », niveau de départ plus élevé… |
| **Social** | Des PNJ à rencontrer, avec des interactions sociales à la façon des Sims : confiance, amitié, mariage, enfants, divorce… Un conjoint ou un enfant pourra devenir le personnage suivant (non prioritaire). |
| **Monde vivant** | Les PNJ vivent indépendamment du joueur, et les lieux changent avec le temps. |
| **Voyages** | Ils passent par des événements. On peut quitter une ville définitivement et ne jamais y revenir. |
| **Métiers** | Une suite d'activités, comme « être aventurier » ne se résume pas à un bouton Combat. Certaines classes s'y prêtent mieux (Artificier pour l'artisanat, Alchimiste pour l'alchimie et la cuisine…). |
| **Contenu** | Les événements sont générés au besoin. L'utilisateur fournira plus tard des campagnes, des suites de quêtes et son **lore**, déjà bien avancé. |
| **Combat** | Proche de D&D : actions de classe, sorts à emplacements, états cumulables (poison, brûlure, étourdi, affaibli, protection), actions « préparées » des ennemis visibles à l'avance. Le joueur contrôle héros et compagnons. Détails dans modele_donnees.md › Combat. |
| **Équipement** | Il s'obtient par le butin, l'achat et la forge. |
| **Difficulté** | La mortalité dépend des risques pris par le joueur. |
| **Présentation** | Le style pixel art actuel convient, et le son viendra plus tard. |
| **Tests** | Des testeurs sont disponibles facilement. |

### 9.4 Décisions de la v0.4 (réponses aux questions du 2026-10-12)

| Sujet | Décision |
|---|---|
| **Priorité** | Les **systèmes** d'abord ; l'univers et le lore plus tard. Pas de limite au MVP. |
| **Ton** | Proche de D&D, Genshin, Xenoblade Chronicles, Magic : de l'humour dans les moments calmes, du sérieux dans les moments sombres. |
| **Structure** | **Monde ouvert**, avec des **amorces de campagnes** : des suites de quêtes reliées par un fil conducteur. |
| **Voyages** | Un événement « voyage » dont la durée dépend de la destination et du **moyen de transport** ; selon la durée, il déclenche au hasard un ou plusieurs **événements en route** (embuscade, rencontre, se perdre…). |
| **Passer du temps** | Des activités longues (« travailler un an », « s'installer »…) par tranches de **1, 2, 5 ou 10 ans**. |
| **Âge et majorité** | Majorité à **18 ans pour toutes les espèces** : aucun personnage jouable en dessous, et les événements adultes (couple…) l'exigent. Le gobelin commence donc à 18 ans. Enfance jouable : non pour l'instant. |
| **PNJ** | Génération **progressive**, comme un MJ de JdR papier : un PNJ apparaît avec un rôle, un nom et une histoire « de surface ». Plus le joueur s'intéresse à lui, plus on lui génère un passé, des proches et du lore ; ses réponses deviennent des **faits** enregistrés. Quelques PNJ restent écrits à la main. |
| **Mariage et enfants** | Condition d'âge ; **aucune restriction entre espèces**, la descendance est décrite dans [especes.md](especes.md). Enfants non jouables pour l'instant. |
| **Monde vivant** | Le monde évolue sans le joueur. |
| **Métiers** | Accessibles selon les compétences, la classe et les choix. Chaque métier est une suite d'activités, presque un **mini-jeu**, au même titre que le combat et l'exploration pour l'aventurier : artisanat, cuisine… sont des **sous-systèmes**. |
| **Classes et espèces** | Listées par l'auteur dans [classes.md](classes.md) et [especes.md](especes.md). |
| **Économie** | Des **boutiques** (achat et revente). La forge permet de **fabriquer** à partir de matériaux **et** d'**améliorer** contre de l'or. Des **objets magiques** à effets spéciaux. |
| **Progression** | Emplacements de sorts et aptitudes par niveau selon les **tables du SRD 5.1** (pour l'instant). **Multiclassage** prévu. |
| **Compagnons** | Système proche de **Baldur's Gate 3** : recrutement, approbation, dialogues, équipement, départ possible. |
| **Interface** | Un bouton **Inventaire** dans la fiche, qui ouvre un menu (équiper, utiliser, jeter). Un **journal** de la vie en cours. Des **options** (vitesse et désactivation des dés, taille du texte, langue). |
| **Tests** | Versions **Windows et Web**. Le recueil des retours et le calendrier des tests sont gérés par l'auteur. |

### 9.5 Décisions de la v0.5 (réponses du 2026-10-13)

Le détail est dans les catalogues ([equipements.md](equipements.md), [objets.md](objets.md),
[types_de_degats.md](types_de_degats.md), [etats.md](etats.md), [dons.md](dons.md), [competences.md](competences.md),
[classes.md](classes.md), [especes.md](especes.md)), rubriques « Décisions ».

| Sujet | Décision |
|---|---|
| **Commerce** | Tout marchand rachète tout (sauf les objets de quête). La Persuasion joue sur l'achat et la revente. |
| **Encombrement** | Malus à tous les jets de FOR et DEX, proportionnel : armure trop lourde pour sa Force, et poids porté au-delà de la capacité (selon la Force). |
| **Emplacements** | Couvre-chef, torse, gants, jambes, chaussures, collier (1), anneaux (2), plus les deux mains. |
| **Simplicité** | Ni munitions, ni usure, ni objets périssables, ni limite d'objets magiques ; pas d'héritage d'objets en général. |
| **Inventaire** | Objets de quête, filtres et recherche. |
| **À venir** | Récolte de matériaux, identification, jet de compétence pour fabriquer, environnement (aussi en combat), avantage et désavantage, états hors combat, dons du SRD 5.2 en version complète, dons à choix, choix des compétences de classe, sous-classes (niveaux 1 à 3), ascendances du tieffelin (feu, froid, nécrotique). |
| **Compétences** | Trois compétences de métier génériques : Artisanat, Arts, Potions et cuisine. Leur progression sera liée au niveau (système à trouver). |
| **Améliorations** | Tous les 4 niveaux : un attribut **et** un don. |

### 9.6 Décisions de la v0.6 (réponses du 2026-10-13)

| Sujet | Décision |
|---|---|
| **Création de personnage** | À retravailler plus tard ([creation_personnage.md](creation_personnage.md)). |
| **Jets de sauvegarde** | À réexaminer : usages et options dans [jets_de_sauvegarde.md](jets_de_sauvegarde.md). |
| **Points de vie** | Selon la **taille** et l'**endurance** (Constitution), pas la classe ; peut-être pas de progression par niveau (fragilité voulue). |
| **Tailles** | Échelle de −4 (insecte) à 5+ (colosse) ; humain 0, nain et enfant −1, ogre 2, géant 3, baleine 4. |
| **Mort** | Pas de jets contre la mort : un membre du groupe qui tombe est inconscient tant qu'un autre tient debout, et il est ramené à lui après le combat ; si tout le groupe tombe, c'est la mort. Un moyen de revenir à la vie est à prévoir. |
| **Classes suivantes** | Barde, Rôdeur, Clerc, Druide, Artificier. Le système de magie (sorts appris) reste à définir. |
| **Économie d'actions** | Celle de D&D : une action et une action bonus par tour. |
| **Réactions** | Les actions gardées à la fin du tour servent à esquiver (Physique DEX) ou parer (Physique ou Armes de mêlée, DEX ; distance : avec un bouclier) ; contresort plus tard. L'attaque ne touche que si elle dépasse le jet de défense. |
| **Repos** | Un bouton toujours accessible : camper en zone sauvage, nuit à l'auberge (payante) en ville. |
| **Multiclassage** | Libre : à chaque niveau, on choisit la classe. |
| **IA** | Combat automatique par personnage ; archétypes d'IA plus tard. |
| **Terrain** | Pistes à étudier ([environnement.md](environnement.md)). |
| **Voyages, temps long** | Se perdre (Survie) et ses événements ; résumé pour les années passées ; mort des PNJ ; journal chronologique et filtrable. |
| **Métiers** | Pas de « métier jouable » : un métier se dessine naturellement (forger et vendre fait de vous un forgeron) ; la fabrication suit la description d'Artisanat ; on vit de la vente de ses créations. |
| **Social** | Activités (dîner, promenade, entraînement), PNJ qui prennent l'initiative, enfants retrouvables d'une vie à l'autre, effets de la réputation (prix, accueil, événements), échanges entre PNJ. Pas d'usure des relations pour l'instant. |
| **Équipement** | 1 collier, 2 anneaux ; des reliques peuvent traverser les vies. |
| **Lore** | Fiches [monde.md](monde.md), [lieux.md](lieux.md), [factions.md](factions.md) à remplir par morceaux. |
| **Contenu** | Des événements de test peuvent être générés au besoin. |
| **Images** | Le pixel art actuel convient (le rapprocher de BG3 serait un plus). |

### 9.7 Décisions de la v0.7 : le système de dés (2026-10-13)

Le d20 de D&D est remplacé par des **réserves de d10 à succès**, inspirées d'Aetherpunk. Toutes les règles sont dans
[systeme_de_jeu.md](systeme_de_jeu.md). En résumé :

| Sujet | Décision |
|---|---|
| **Jet** | [Compétence] d10 contre un seuil (l'attribut) ; ≤ seuil = succès ; 9 et 10 jamais, 1 toujours et relancé ; réussi si les succès atteignent la difficulté (1 à 8+) |
| **Attributs** | De 3 à 8 pour un humain, 4 pour une personne ordinaire ; au-delà de 8, des dés en plus au seuil 8 |
| **Critiques** | Réussite critique N tous les 3 succès supplémentaires ; échec critique : aucun succès (à confirmer) |
| **Bonus et malus** | Sur la difficulté en général, sinon en dés ; jamais moins d'un dé (le seuil baisse) ; option « dés nombreux » |
| **Combat** | Deux actions par tour ; actions gardées = réactions (esquive, parade, contre-attaque) ; réactions non utilisées = Préparé (+2 dés) ; Esquive naturelle (DEX ÷ 3) en mêlée, Couvert à distance ; Armure qui baisse le seuil des dégâts ; dégâts = succès ; critiques = relances ; attaques surprises |
| **Initiative** | 1d10 + DEX + INT ; égalité : DEX, puis INT, puis au hasard |
| **Sauvegardes** | Remplacées par « Résister » : une compétence contre l'attribut (option B de [jets_de_sauvegarde.md](jets_de_sauvegarde.md)) |

## 10. Prochaines étapes proposées

1. ~~Répondre aux questions ouvertes du §9.~~
2. ~~Passer le renderer en Compatibility et initialiser git.~~
3. ~~Définir le modèle de données~~ : voir [modele_donnees.md](modele_donnees.md). Ennemis, actions de combat et compagnons ajoutés avec le combat.
4. ~~Coder le moteur d'événements et un écran minimal~~ : 18 événements, placeholders pixel art, tests automatisés.
5. ~~Écran de création de personnage~~ (espèce, genre, classe, passé, achat de points, nom, apparence), ~~lancers de
   dés animés~~ et ~~règles de vieillissement~~.
6. ~~Ajouter le combat~~ : initiative, attaques contre la CA, critiques, sorts et emplacements, objets, fuite, compagnon contrôlé par le joueur, issues victoire / fuite / défaite (mortelle ou K.-O.), banc d'équilibrage.
7. ~~**Refonte du combat**~~ : états cumulables, intentions ennemies, invocations, 4 places par camp, sprites à
   l'échelle de la taille, nouvel écran de combat. Les decks ont été essayés puis abandonnés au profit d'actions façon D&D.
8. ~~Sauvegarde (vie en cours et méta) et écran titre~~ : autosauvegarde, reprise des combats interrompus,
   chronique des vies sur l'écran titre.
9. ~~Creator Points et chronique~~ : gain selon l'XP de la vie, bonus de départ (attributs, niveau, or), déblocages
   achetables. Valeurs provisoires, à ajuster avec les testeurs.
10. ~~Règle de majorité (18 ans), catalogues [classes.md](classes.md) et [especes.md](especes.md).~~

**Feuille de route des systèmes (v0.4)**, dans l'ordre proposé :

11. ~~**Progression D&D**~~ : emplacements de sort par niveau (tables SRD, sorts lancés à un niveau supérieur),
    aptitudes par niveau (Fougue, Attaque supplémentaire, Inflexible, Expertise, Attaque sournoise qui monte, Esquive
    instinctive, Dérobade, Talent fiable, tours de magie qui montent, Rayons ardents, Boule de feu), jets de
    sauvegarde maîtrisés (événements et combat). Détail dans [classes.md](classes.md). Restent pour plus tard :
    sous-classes, actions bonus, repos courts, choix des sorts.
12. ~~**Inventaire et équipement**~~ : écran Inventaire depuis la fiche (touche I), sac du groupe partagé,
    équipement des compagnons, 10 emplacements, poids et encombrement, filtres et recherche, objets de quête, butin
    d'équipement, premiers objets magiques.
    Fiches de conception [types_de_degats.md](types_de_degats.md) et [etats.md](etats.md), avec leurs questions.
13. ~~**Économie**~~ : à Brumeval, armurerie, herboristerie et forge (achat, revente, stock qui se reconstitue),
    prix négociés par la Persuasion, fabrication par recettes (forge, alchimie), amélioration +1 à +3. Fiches
    [equipements.md](equipements.md) et [objets.md](objets.md).
14. ~~**Règles D&D à compléter**~~ : avantage et désavantage (attaques, sauvegardes, fuite, tests) et 8 états
    qui en dépendent, sort Sommeil ; système de choix (création et hub) : compétences de classe, ascendance du
    tieffelin, don de l'humain, dons à options, Style de combat ; dons du SRD 5.2 en version complète ;
    sous-classes au niveau 3 (Champion, Évocateur, Voleur) ; emplacement de cape rétabli.
14 bis. ~~**Refonte des compétences**~~ : 19 compétences à rangs (départ 1, 2 si instinctive, Magie 0 hors lanceurs),
    plusieurs attributs possibles (le meilleur par défaut, option pour choisir), compétences d'armes et de Magie
    pour les attaques et le DD des sorts, langues, Perception passive, actions communes (Se cacher, Intimider,
    Premiers soins), rangs des créatures. Détail dans [competences.md](competences.md).
14 ter. ~~**Interactions sociales**~~ : PNJ du monde générés progressivement (habitués, gardes et villageois à
    chercher), traits, goûts, humeur, faits révélés, souvenirs entre les vies ; jauges Amitié / Amour / Confiance,
    statuts, réputation par lieu ; dialogue à la Sims, échange à la BG3 (acheter, vendre, offrir, demander) ;
    romance (couple, relation libre, polyamour, fiançailles, mariage, enfants, rupture, jalousie) ; monde autonome
    (liens, couples, rumeurs, naissances) ; langues cryptées ; approbation et recrutement des compagnons ; carnet.
    Détail dans [social.md](social.md). Aussi : initiative lancée en une fois.
14 quater. ~~**Règles de la v0.6**~~ : tailles de −4 à 5 et PV selon la Constitution et la taille ;
    inconscience au lieu de la mort ; action et action bonus ; réactions (esquive, parade) ; IA par
    personnage ; repos (camp, auberge) ; multiclassage libre ; Artisanat avec test et métiers qui se dessinent ;
    activités, initiatives des PNJ, réputation ; Vigilant converti ; fiches de conception et de lore.
14 quinquies. ~~**Système de dés d10**~~ : réserves de d10 partout (événements, social, artisanat, combat), deux
    actions par tour, réactions, Préparé, Esquive naturelle, Couvert, Armure, critiques, surprise, initiative d10 ;
    données converties (attributs, armes, armures, créatures, sorts, états, difficultés).
15. **Temps long** : événement voyage (durée, transport, événements en route, se perdre), activités de 1, 2, 5 ou
    10 ans, journal de la vie.
16. **PNJ générés progressivement** et relations : faits enregistrés, jauges, interactions sociales.
17. **Mariage et enfants**, puis **monde autonome** (PNJ qui vieillissent, lieux qui changent).
18. **Compagnons à la BG3** : approbation, dialogues, départ.
19. **Métiers en sous-systèmes**, en commençant par la forge.
20. **Multiclassage**.
21. **Options** (dés, texte, langue) et **exports** Windows et Web dès qu'une version de test est voulue.

## 11. Backlog (idées validées, non prioritaires)

Les grands chantiers (temps long, social, monde vivant, voyages, métiers, économie, multiclassage, compagnons) sont
désormais dans la feuille de route du §10. Restent ici :

- **Conjoint ou enfant comme personnage suivant**, et enfance jouable.
- **Creator Points** : barème à ajuster avec les testeurs ; autres bonus possibles.
- **Combat** : contresort, archétypes d'IA (cibler les blessés, se soigner, fuir), revenir à la vie.
- **Classes** : Barde, Rôdeur, Clerc, Druide, Artificier ; système de magie (sorts appris) à définir.
- **Lore et univers** : fournis par l'auteur, à intégrer (noms de lieux, factions, campagnes).
- **Son et musique**, **pipeline d'images IA**, **traduction anglaise**.

## 12. Outils de développement

- **Banc d'équilibrage** : `tools/combat_bench.tscn` (taux de victoire par classe et par rencontre).
- **Mode debug** : F12 en jeu, ou lancer avec `-- --debug`. Il affiche les choix verrouillés (grisés, avec la raison),
  qui sont cachés en jeu normal.
