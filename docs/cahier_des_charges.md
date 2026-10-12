# Cahier des charges — Lifantasy (titre provisoire)

> Version 0.2 — 2026-10-12 — document vivant, à mettre à jour au fil des décisions.

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

L'objectif du MVP est d'avoir **une boucle complète, de bout en bout**, avec peu de contenu. Le MVP sert à vérifier que
le jeu est amusant avant de produire du contenu en masse.

**Dans le MVP :**
- [x] Création de perso : **2 espèces × 2 classes**, passé, genre, attributs par achat de points, nom.
- [ ] **1 ville + 1 zone sauvage** (forêt).
- [ ] Moteur d'événements data-driven : conditions, choix, effets, flags, tests de stats.
- [ ] **~30 événements**, dont 1 petite chaîne de quête et 1 événement de recrutement de compagnon.
- [ ] Combat tour par tour : équipe de **2 maximum** (héros + 1 compagnon), 4 ou 5 types d'ennemis, 1 boss.
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
| **Temps** | **Plusieurs actions par jour** | Proposition : 3 créneaux (matin, après-midi, soir), et le jour avance quand ils sont tous utilisés. |
| **Vieillissement** | **Oui, dès le MVP** | Au-delà de l'âge limite de l'espèce, chaque année retire 1 à un attribut tiré au hasard. Un attribut à 0 tue le personnage. |
| **Vocabulaire** | **Espèce**, pas « race » | Utilisé partout : données, code, interface. |
| **Espèce** | Taille et âges, **aucun effet sur les attributs** | La taille (Petite, Moyenne…) est une variable du personnage, utilisable dans les conditions. |
| **Passé** | Choisi à la création | Il donne 2 compétences maîtrisées (et parfois de l'or ou des objets). Il est utilisable dans les conditions d'événements. |
| **Genre** | Femme, homme ou non-binaire | Aucun effet sur l'apparence ni sur les règles. Il sert aux accords dans les textes, avec la syntaxe `{g:masculin\|féminin\|neutre}`. |
| **Combat** | Tour par tour, **sans positionnement** | Initiative, actions, sorts, objets ; les jets s'inspirent de D&D (d20 + modificateur contre la classe d'armure). |
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
- **Dons** : hors MVP. Les **traits** d'espèce et de classe en tiendront lieu au début.
- **Niveaux** : de 1 à 5 maximum pour le MVP.

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

## 10. Prochaines étapes proposées

1. ~~Répondre aux questions ouvertes du §9.~~
2. ~~Passer le renderer en Compatibility et initialiser git.~~
3. ~~Définir le modèle de données~~ : voir [modele_donnees.md](modele_donnees.md). Les ennemis restent à définir, avec le combat.
4. ~~Coder le moteur d'événements et un écran minimal~~ : 18 événements, placeholders pixel art, tests automatisés.
5. ~~Écran de création de personnage~~ (espèce, genre, classe, passé, achat de points, nom, apparence), ~~lancers de
   dés animés~~ et ~~règles de vieillissement~~.
6. Ajouter le combat.
7. Ajouter sauvegarde et méta.
8. Produire le contenu du MVP, puis faire tester.

## 11. Backlog (idées validées, non prioritaires)

- **Passer des années** : un bouton (ou une action) pour faire passer plusieurs années d'un coup, par exemple en
  s'installant comme forgeron. Sans lui, la vieillesse n'arrive presque jamais avec l'échelle de temps actuelle
  (10 jours par an).

## 12. Outils de développement

- **Mode debug** : F12 en jeu, ou lancer avec `-- --debug`. Il affiche les choix verrouillés (grisés, avec la raison),
  qui sont cachés en jeu normal.
