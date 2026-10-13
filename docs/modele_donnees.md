# Modèle de données — Lifantasy

Tout le contenu du jeu est décrit en JSON dans `claude_rpg/data/`. Au lancement, ces fichiers sont chargés et
**vérifiés** : une faute de frappe dans un id, un objet inexistant ou un champ manquant s'affiche en rouge dans le jeu et
dans la console Godot. Les tests automatisés le signalent aussi.

| Fichier | Contenu |
|---|---|
| `rules.json` | Achat de points, genres, tailles, moments de la journée, étapes de vie, progression |
| `abilities.json` | Attributs (API `Abilities`) |
| `skills.json` | Compétences (API `Skills`) |
| `feats.json` | Dons (API `Feats`) |
| `equipment.json` | Armes, armures, boucliers (API `Equipment`) |
| `damage_types.json` | Types de dégâts (API `DamageTypes`) |
| `status_effects.json` | États : empoisonné, charmé… (API `StatusEffects`) |
| `species.json` | Espèces : taille, âges, vieillissement, noms, apparence des portraits |
| `classes.json` | Classes : dé de vie, modèle d'attributs, compétences maîtrisées, objets de départ |
| `backgrounds.json` | Passés : compétences maîtrisées, or et objets de départ éventuels |
| `items.json` | Objets hors équipement, avec une `category` : `consumable` (`use`, ex. `{"heal": "2d4+2"}`), `material`, `treasure`. Les ids sont uniques entre `items.json` et `equipment.json` |
| `shops.json`, `recipes.json` | Boutiques et recettes (voir Économie) |
| `creatures.json` | Bestiaire : ennemis et invocations (API `Creatures`) |
| `actions.json` | Actions de combat des classes : attaques, sorts, capacités (API `Actions`) |
| `companions.json` | Compagnons recrutables |
| `locations.json` | Lieux proposés au joueur (l'ordre du fichier est l'ordre d'affichage) |
| `events/*.json` | Événements, un fichier par lieu ou par thème (tous les `.json` du dossier sont chargés) |

> ⚠️ Le JSON n'accepte ni commentaires ni virgule finale. Les nombres sont lus comme des décimaux : le code les convertit.

---

## Événement

```json
{
	"id": "forest_wolf",
	"location": "forest",
	"weight": 5,
	"repeat": "always",
	"cooldown_days": 0,
	"conditions": [],
	"title": "Un loup gris",
	"text": "Un grognement sourd. Un loup vous fixe, {name}.",
	"choices": [ ... ]
}
```

| Champ | Obligatoire | Description |
|---|---|---|
| `id` | oui | Identifiant unique (snake_case, préfixé par le lieu de préférence) |
| `location` | oui | Lieu où l'événement peut être tiré. `null` = jamais tiré au hasard, seulement atteint par `goto` |
| `weight` | non (10) | Poids relatif dans le tirage. 30 = très prioritaire, 3 = rare |
| `repeat` | non (`always`) | `always`, `once_per_life` (une fois par personnage) ou `once_per_world` (une seule fois, toutes vies confondues) |
| `cooldown_days` | non (0) | Nombre de jours avant de pouvoir revoir l'événement |
| `conditions` | non | Liste de conditions (ET logique) pour que l'événement soit tirable |
| `title`, `text` | oui | Textes affichés. Variables disponibles : `{name}`, `{species}`, `{class}`, `{background}`, et l'accord au genre (voir plus bas). Le BBCode est accepté (`[i]`, `[b]`, `[color=…]`) |
| `art` | non | Type de décor du placeholder (`forest`, `town`, `home`). Par défaut, celui du lieu |
| `choices` | oui | Au moins un choix |

**Tirage :** quand le joueur choisit un lieu, on garde les événements de ce lieu qui sont éligibles (repeat, cooldown,
conditions), puis on en tire un au hasard en fonction des poids. Si aucun n'est éligible, un événement « Un moment
calme » est utilisé.

**Temps :** une séquence d'événements consomme **un créneau** (matin → après-midi → soir → jour suivant), quel que soit
le nombre de `goto` enchaînés. L'effet `pass_time` en ajoute.

## Choix

Un choix est soit **direct** (`outcome`), soit **avec test** (`check`, `success`, `failure`) :

```json
{
	"id": "fight",
	"text": "L'affronter",
	"conditions": [{"type": "class", "in": ["wizard"]}],
	"check": {"skill": "athletics", "dc": 13},
	"success": {"text": "La bête s'effondre.", "effects": [{"type": "xp", "amount": 100}]},
	"failure": {"text": "Ses crocs se referment sur vous.", "effects": [{"type": "hp", "amount": -6, "cause": "Dévoré par un loup"}]}
}
```

| Champ | Description |
|---|---|
| `conditions` | Si elles ne sont pas remplies, le choix est **caché**. En mode debug (F12), il est affiché grisé, avec la raison (ex. « INT 12+ ») |
| `check` | Test d20 : `{"skill": "<compétence>", "dc": N}`, `{"ability": "<attribut>", "dc": N}` ou `{"save": "<attribut>", "dc": N}` (jet de sauvegarde, avec la maîtrise si la classe le maîtrise) |
| `outcome` / `success` / `failure` | `{"text": "...", "effects": [...]}` |

**Tests :** on lance d20 + modificateur et on compare au DD. Un 20 naturel réussit toujours, un 1 naturel échoue
toujours. Le pourcentage de réussite est affiché au joueur. Le modificateur vaut celui de l'attribut, plus le bonus de
maîtrise si la classe maîtrise la compétence.

Repères de DD : 10 facile · 13 moyen · 15 difficile · 18+ très difficile.

## Conditions

Chaque condition est un objet avec un champ `type`. Une liste de conditions est un **ET** logique.

| type | Champs | Vrai si… |
|---|---|---|
| `flag` | `id` | Le flag de la vie en cours est posé |
| `world_flag` | `id` | Le flag du monde (persistant entre les vies) est posé |
| `unlocked` | `id` | Le déblocage existe (`species:elf`, `class:rogue`) |
| `seen` | `event` | L'événement a déjà été vu dans cette vie |
| `ability` | `id`, `min`?, `max`? | La valeur d'attribut est dans l'intervalle |
| `skill_proficient` | `id` | Le personnage maîtrise la compétence |
| `species` / `class` / `background` | `in` (liste) | L'espèce, la classe ou le passé fait partie de la liste |
| `size` | `in` (liste) | La taille (`tiny`, `small`, `medium`, `large`) fait partie de la liste |
| `gender` | `in` (liste) | Le genre (`female`, `male`, `nonbinary`) fait partie de la liste |
| `life_stage` | `in` (liste) | L'étape de vie (`child`, `teen`, `adult`, `elder`, `venerable`) fait partie de la liste |
| `age` / `gold` / `level` | `min`?, `max`? | La valeur est dans l'intervalle |
| `item` | `id`, `min`? (1) | Le personnage possède au moins `min` exemplaires de l'objet |
| `companion` | `id` | Le compagnon (`companions.json`) fait partie du groupe |
| `has_feat` | `id` | Le personnage possède le don |
| `equipped` | `id` | Le personnage porte cet équipement |
| `defense` | `kind`, `id` | Le personnage a cette défense (ex. `{"kind": "resistance", "id": "fire"}`) |
| `time` | `in` (liste) | Le moment de la journée (`morning`, `afternoon`, `evening`) fait partie de la liste |
| `not` | `condition` | La sous-condition est fausse |
| `any` | `conditions` (liste) | Au moins une des sous-conditions est vraie (OU) |

## Effets

| type | Champs | Effet |
|---|---|---|
| `set_flag` / `clear_flag` | `id` | Pose ou retire un flag de la vie en cours |
| `set_world_flag` / `clear_world_flag` | `id` | Pose ou retire un flag du monde, **conservé après la mort** |
| `unlock` | `id` | Débloque une espèce ou une classe pour les vies suivantes (`species:elf`, `class:rogue`) |
| `gold` | `amount` | Ajoute ou retire de l'or (jamais sous 0) |
| `hp` | `amount`, `cause`?, `damage_type`? | Soigne ou blesse. Avec `damage_type`, les défenses du personnage s'appliquent. À 0 PV, le personnage meurt, et `cause` s'affiche sur l'écran de mort |
| `heal_full` | — | Rend tous les PV |
| `xp` | `amount` | Donne de l'XP. Les montées de niveau sont automatiques |
| `ability` | `id`, `amount`, `cause`? | Modifie un attribut. Un attribut à 0 tue le personnage |
| `add_item` / `remove_item` | `id`, `count`? (1) | Ajoute ou retire des objets du sac (id de `items.json` ou de `equipment.json`) |
| `goto` | `event` | Enchaîne directement sur un autre événement, après le bouton « Continuer » |
| `pass_time` | `slots`?, `days`? | Fait passer du temps en plus |
| `die` | `cause`? | Tue le personnage |
| `long_rest` | — | Repos long : PV et emplacements de sort du groupe au maximum |
| `recruit` | `companion` | Le compagnon rejoint le groupe (dans la limite de `max_companions`) |
| `combat` | `enemies`, … | Lance un combat (voir plus bas). **Doit être le dernier effet de la liste** |
| `add_feat` | `id` | Le personnage obtient un don |
| `equip` | `id` | Équipe une arme, une armure ou un bouclier à son emplacement |
| `add_defense` / `remove_defense` | `kind`, `id` | Ajoute ou retire une défense propre au personnage (`resistance`, `immunity`, `vulnerability` + type de dégâts, ou `status_immunity` + état) |

## Combat

Un combat se lance avec l'effet `combat` :

```json
{
	"type": "combat",
	"enemies": ["bandit", "bandit"],
	"flee": true,
	"flee_dc": 12,
	"on_defeat": "death",
	"victory": {"text": "Les brigands gisent dans la boue.", "effects": []},
	"fled": {"text": "Vous les semez.", "effects": []},
	"defeat": {"text": "…", "effects": []}
}
```

| Champ | Description |
|---|---|
| `enemies` | Ids de `creatures.json`. Les doublons sont numérotés (Brigand A, Brigand B). Le total des places ne doit pas dépasser la capacité d'un camp |
| `flee` (true), `flee_dc` (12) | La fuite est-elle possible, et son DD (d20 + DEX) |
| `on_defeat` | `death` (par défaut) : le héros à 0 PV meurt, les compagnons à 0 PV aussi. `knockout` : tout le monde se relève à 1 PV, comme pour une bagarre de taverne |
| `victory` / `fled` / `defeat` | Texte et effets de chaque issue. `defeat` ne sert qu'en `knockout` |

### Déroulement

C'est un combat proche de D&D 5e. Les réglages sont dans `rules.json › combat`.

- **Initiative** : chacun lance d20 + DEX (+ bonus d'initiative).
- **Début de chaque tour** : les états agissent (poison, brûlure…) puis perdent leurs charges. Un combattant étourdi
  passe son tour.
- **Héros et compagnons** sont contrôlés par le joueur. À leur tour, ils font **une action** :
  - une action de leur classe (attaque, sort, capacité) ;
  - un objet ;
  - la fuite ;
  - ou passer leur tour.

  Une action `free` (Fougue) ne consomme pas l'action du tour, et l'effet `extra_action` en donne une de plus :
  le tour continue tant qu'il en reste (`Combat.actions_left`).
- **Attaque supplémentaire** : l'action Attaque (`attack_action`) frappe 1 + `extra_attack` fois. Si la cible tombe,
  les coups suivants visent l'ennemi le plus faible.
- **Jets de sauvegarde** : un effet avec `save` fait lancer à la cible d20 + modificateur (+ maîtrise si sa classe
  maîtrise cette sauvegarde) contre le DD des sorts de l'acteur (8 + maîtrise + attribut d'incantation), le `dc` de
  l'effet ou le `save_dc` de la créature.
- **Réactions** (première version) : l'Esquive instinctive divise par deux une attaque par round ; la réaction revient
  au début du tour du personnage.
- **Créatures** (ennemis, invocations) : elles jouent seules (IA). Un ennemi qui tire une action `prepared` l'annonce
  (« Prépare : … », visible au-dessus de lui), puis l'exécute à son tour suivant.
- **Attaque** : d20 + bonus contre la CA. Un 20 naturel est un critique (dés doublés), un 1 naturel rate toujours.
  Le bonus vaut le modificateur d'attribut plus la maîtrise.
- **Places** : chaque camp a `side_capacity` places (4). Une créature en occupe `size_slots[taille]` : ½ pour une petite,
  1 pour une moyenne, 2 pour une grande. Sa taille à l'écran suit `sprite_scale`.
- **Récompenses à la victoire** : l'XP de tous les ennemis va à chaque membre du groupe encore debout, et l'or et le
  butin s'y ajoutent.

**Équilibrage :** `tools/combat_bench.tscn` joue chaque rencontre des centaines de fois. Il affiche le taux de
victoire par classe, seul et avec un compagnon, ainsi que la durée moyenne en rounds.

### Actions de classe (`actions.json`)

```json
{
	"id": "magic_missile",
	"name": "Projectile magique",
	"description": "Trois fléchettes de force qui touchent toujours leur cible.",
	"target": "enemy",
	"cost": "spell_slot",
	"spell_level": 1,
	"effects": [{"type": "damage", "damage": "3d4+3", "damage_type": "force", "upcast": "1d4+1"}]
}
```

| Champ | Description |
|---|---|
| `target` | `enemy`, `all_enemies`, `ally`, `all_allies`, `self`, `none` |
| `effects` | Effets de combat (ci-dessous). Le texte d'aide en est généré automatiquement |
| `cost` | Ressource consommée, rechargée par un repos long (`long_rest`). `spell_slot` : un emplacement de sort d'au moins `spell_level` (le plus bas disponible) ; sinon un id de ressource de la classe ou de ses aptitudes (ex. `indomitable`) |
| `spell_level` | Niveau du sort (1 à 9), obligatoire avec `cost: "spell_slot"` |
| `per_combat` | Nombre d'utilisations par combat |
| `attack_action` | `true` pour l'action Attaque, qui profite d'Attaque supplémentaire |
| `free` | `true` si l'action ne consomme pas l'action du tour (Fougue) |

Une action sans `cost` ni `per_combat` est utilisable à volonté : attaque d'arme, tours de magie.

**Sorts à un niveau supérieur :** si un effet d'un sort a `upcast`, le sort est proposé une fois par niveau
d'emplacement disponible (« Projectile magique (niv. 3) »), avec `upcast` ajouté aux dégâts par niveau au-delà de
`spell_level`. Sinon, le sort prend le plus bas emplacement disponible.

Chaque classe déclare :
- `actions` : ses actions dès le niveau 1 ;
- `features` : ses aptitudes par niveau (voir ci-dessous) ;
- `saving_throws` : ses deux jets de sauvegarde maîtrisés ;
- `equipment` : son équipement ;
- `spellcasting` : l'attribut d'incantation (pour les sorts, `"ability": "spell"`) ;
- `spell_slots` : `full` (lanceur complet) ou `half` (demi-lanceur), qui renvoie aux tables de
  `rules.json › spell_slots` (SRD 5.1) ;
- `resources` : d'autres ressources fixes, rechargées par un repos long.

### Aptitudes de classe (`classes.json › features`)

```json
{"level": 5, "id": "extra_attack", "name": "Attaque supplémentaire", "description": "L'action Attaque frappe deux fois.",
 "modifiers": [{"type": "extra_attack", "amount": 1}]}
```

| Champ | Description |
|---|---|
| `level` | Niveau de classe auquel l'aptitude est acquise |
| `actions` | Actions gagnées (ids de `actions.json`) |
| `modifiers` | Modificateurs (voir Modificateurs) |
| `resources` | Ressources ajoutées, qui s'additionnent entre aptitudes (Inflexible : 1 + 1 + 1) |

Une aptitude sans aucun de ces champs est purement descriptive : par exemple « Tours de magie renforcés », dont l'effet
vient de `scaling`. En montant de niveau, les aptitudes et les nouveaux emplacements sont annoncés, et les ressources
gagnées sont immédiatement disponibles. L'API correspondante est `ClassFeatures`.

### Effets de combat

Ils sont communs aux actions des classes (`actions.json`) et à celles des créatures (`creatures.json`).

| type | Champs | Effet |
|---|---|---|
| `attack` | `weapon: true` (arme du personnage), ou `weapon: "<id>"` (arme du catalogue), ou `damage` + `damage_type` ; `ability`? (`spell`…), `to_hit`? (créatures), `extra_damage`?, `add_mod`? | Jet d'attaque contre la CA, puis dégâts. **Les effets qui suivent ne s'appliquent que si l'attaque touche** |
| `damage` | `damage`, `damage_type` | Dégâts automatiques |
| `extra_action` | — | Une action de plus ce tour |
| `heal` | `amount` (`level` = niveau) | Soins |
| `status` | `status`, `stacks` | Ajoute des charges d'état (sauf immunité) |
| `cleanse` | `status` (ou `negative`) | Retire un état, ou tous les états négatifs |
| `summon` | `creature` | Invoque une créature dans son camp (s'il reste de la place) |

Champs facultatifs, valables pour tout effet :
- `save` : `{"ability": "dex", "half"?: true, "dc"?: N}`. La cible fait un jet de sauvegarde. Si elle le réussit,
  l'effet est annulé, ou ses dégâts sont divisés par deux avec `half`, et **les effets suivants sont ignorés** comme
  après une attaque ratée. La Dérobade transforme « moitié » en « rien » et « plein » en « moitié ».
- `scaling` : `{"table": "cantrip", "field"?: "damage" | "extra_damage"}`. Le nombre de dés suit le niveau de classe
  (`rules.json › dice_scaling` : `cantrip` 1/2/3/4 dés aux niveaux 1/5/11/17, `sneak_attack` +1d6 tous les deux
  niveaux).
- `upcast` : dégâts ajoutés par niveau d'emplacement au-delà du niveau du sort.
- `bonus_damage` : `[{"damage": "1d4", "damage_type": "fire"}]`, dégâts d'autres types ajoutés à une attaque ou à des
  dégâts. Chaque partie est lancée séparément avec les défenses de son type. Une arme peut aussi en porter
  (`equipment.json`, ex. la Langue de feu).

### États (`status_effects.json`)

Les états se cumulent en charges. Leur mécanique est entièrement décrite dans les données :

| Champ | Effet |
|---|---|
| `tick_damage_per_stack` | Dégâts par charge au début du tour. Sans `tick_damage_type`, ils sont **bruts** (ils ignorent défenses et Protection) ; le Poison inflige des dégâts de poison |
| `tick_max_hp_percent_per_stack` | Dégâts en % des PV max par charge (au moins 1 par charge), comme la Brûlure |
| `tick_damage_type` | Type des dégâts de tick (les défenses s'appliquent alors) |
| `skip_turn` | Passe son tour (Étourdi) |
| `damage_dealt_per_stack` | Modifie les dégâts infligés (Affaibli : -1 par charge) |
| `absorb` | Chaque charge absorbe 1 point de dégâts (Protection) |
| `decay` / `decay_at` | Charges perdues par tour (un nombre, ou `all`), au début (`start`) ou à la fin (`end`) du tour |
| `negative`, `death_cause`, `color` | État négatif (pour `cleanse`), texte de mort, couleur de la pastille |
| `attack_advantage` / `attack_disadvantage` | Avantage / désavantage à ses jets d'attaque |
| `attacked_advantage` / `attacked_disadvantage` | Avantage / désavantage pour qui l'attaque |
| `attacked_critical` | Un coup qui le touche est un critique (Endormi, Paralysé) |
| `save_disadvantage` / `auto_fail_saves` | Liste d'attributs : désavantage à ces sauvegardes / échec automatique |
| `check_disadvantage`, `no_flee` | Désavantage à ses tests (fuite) ; fuite impossible |
| `no_hostile_actions` | Aucune action visant un ennemi (Charmé) |
| `wake_on_damage` | L'état disparaît quand la créature subit des dégâts (Endormi) |

**Avantage et désavantage** : on lance deux d20 et on garde le meilleur (avantage) ou le pire (désavantage) ; si les
deux s'appliquent, ils s'annulent. Ils jouent sur les attaques (états de l'attaquant et de la cible), les jets de
sauvegarde, la fuite, l'initiative (`initiative_advantage`) et les tests d'événement (`"advantage": true`,
`"disadvantage": true` dans `check`, ou `skill_advantage` du personnage). Le plateau de dés grise le dé écarté.

### Créatures (`creatures.json`)

Ce fichier regroupe les ennemis et les invocations.

| Champ | Description |
|---|---|
| `ac`, `hp` | Classe d'armure, et PV sous forme d'expression de dés (`2d6+2`), tirés à chaque combat |
| `abilities` | Attributs (la DEX sert à l'initiative et aux jets de sauvegarde) |
| `saves`?, `save_dc`? | Bonus aux jets de sauvegarde (`{"dex": 2}`), et DD des sauvegardes que ses actions imposent (10 par défaut) |
| `size` | Taille : places occupées et taille du sprite |
| `actions` | `[{"name", "weight", "target", "prepared"?, "effects"}]` : l'IA tire une action selon les poids. `prepared` : annoncée un tour à l'avance |
| `xp`, `gold`?, `loot`? | Récompenses |
| `defenses` | Résistances, immunités et vulnérabilités (voir Défenses) |
| `death_cause` | Texte de l'écran de mort si la créature tue le héros |
| `summon` | `true` pour une invocation |
| `art` | Placeholder : `{"type": "wolf" \| "rat" \| "humanoid", …}` |

Les compagnons sont des personnages : ils utilisent les actions de leur classe, choisies par le joueur.

### Expressions de dés

Elles s'écrivent `XdY+Z`, et les termes peuvent se combiner : `2d6+3`, `1d8+1d6-1`, `5`.

## Règles centralisées (scripts/rules/)

Chaque notion de règle a **un fichier de données** et **un script d'API**. Le reste du code ne lit jamais les données
directement : il passe par l'API. Pour modifier un attribut, une compétence, un don, une arme ou un type de dégâts, il
suffit donc de modifier son JSON. La fiche, l'écran de création, les tests d'événements, le combat et la validation
suivent automatiquement.

| API | Données | Fonctions principales |
|---|---|---|
| `Abilities` | `abilities.json` | `ids()`, `name_of(id)`, `short_of(id)`, `description_of(id)`, `modifier(valeur)` |
| `Skills` | `skills.json` | `ids()`, `name_of(id)`, `ability_of(id)`, `names_of(liste)` |
| `Feats` | `feats.json` | `ids()`, `name_of(id)`, `modifiers_of(id)`, `meets_prerequisites(id, personnage)` |
| `Equipment` | `equipment.json` | `name_of(id)`, `slot_for(id)`, `weapon_damage(id, deux_mains)`, `damage_type_of(id)`, `attack_ability(id, mod_FOR, mod_DEX)`, `armor_class(armure, bouclier, mod_DEX)`, `describe(id)` |
| `DamageTypes` | `damage_types.json` | `ids()`, `name_of(id)`, `is_physical(id)`, `apply(dégâts, type, défenses)` |
| `StatusEffects` | `status_effects.json` | `ids()`, `name_of(id)`, `tick_damage()`, `skips_turn()`, `absorbs()`… |
| `Actions` | `actions.json` | `def(id)`, `name_of(id)`, `text_of(id)`, `resource_name(id)` |
| `Creatures` | `creatures.json` | `def(id)`, `name_of(id)`, `size_of(id)`, `actions_of(id)` |
| `Progression` | `rules.json` | `xp_for(niveau)`, `proficiency_bonus(niveau)`, `advancement_levels()` |
| `Spellcasting` | `rules.json` | `slots(progression, niveau)`, `save_dc(personnage)`, `dice_count(table, niveau)`, `at_level(action, niveau)` |
| `ClassFeatures` | `classes.json` | `of_class(id)`, `up_to(id, niveau)`, `at_level(id, niveau)`, `announce(personnage, niveau)` |
| `Modifiers` | — | `sum(...)`, `grants(...)`, `defenses(...)`, `describe(...)` : interprète les modificateurs |
| `Defenses` | — | `from_dict()`, `to_dict()`, `add()`, `remove()`, `has()`, `merge()`, `describe()` |

### Dons (`feats.json`)

```json
{
	"id": "athlete",
	"name": "Athlète",
	"description": "…",
	"prerequisites": [{"type": "ability", "id": "dex", "min": 13}],
	"modifiers": [{"type": "ability", "id": "str", "amount": 1}, {"type": "skill_rank", "id": "physique", "amount": 1}]
}
```

Les prérequis s'écrivent comme les conditions des événements. `category` vaut `origin` (dons d'origine) ou `general`.

**Obtention d'un don :**
- **Passé** : chaque passé accorde un don dès la création (`backgrounds.json › feat`, obligatoire).
- **Niveau** : aux niveaux d'amélioration (`rules.json › advancement_levels`, par défaut 4, 8, 12, 16 et 20), le
  personnage, héros ou compagnon, place +1 dans un attribut au choix (20 au maximum) puis choisit un don parmi ceux
  dont il remplit les prérequis. Le contenu d'une amélioration se règle dans `advancement`, et l'API correspondante est
  `Progression`. L'écran de choix s'ouvre avant le retour au hub.
- **Événement** : l'effet `add_feat`.
- **Compagnon** : il peut en avoir d'office dans `companions.json` (`feats`).

### Modificateurs

Les dons, les espèces et les équipements peuvent porter des `modifiers`. Ils s'appliquent automatiquement au personnage.

| type | Champs | Effet |
|---|---|---|
| `ability` | `id`, `amount` | Bonus d'attribut. **Interdit pour une espèce** |
| `skill_rank` | `id`, `amount` | Rangs en plus dans une compétence |
| `hp_per_level` | `amount` | PV max en plus, à chaque niveau |
| `initiative` | `amount` | Bonus d'initiative |
| `ac` | `amount` | Bonus de CA |
| `weapon_damage` | `amount` | Bonus aux dégâts des attaques d'arme |
| `weapon_attack` | `amount` | Bonus aux jets d'attaque avec une arme |
| `saving_throws` | `amount` | Bonus à tous les jets de sauvegarde |
| `resistance` / `immunity` / `vulnerability` | `damage_type` | Défense contre un type de dégâts |
| `status_immunity` | `status` | Immunité à un état |
| `save_proficiency` | `id` | +1 rang à un jet de sauvegarde |
| `extra_attack` | `amount` | Attaques en plus pour l'action Attaque |
| `uncanny_dodge` | — | Une fois par round, les dégâts d'une attaque reçue sont divisés par deux |
| `evasion` | — | Sauvegarde de DEX pour moitié : rien si elle réussit, moitié si elle échoue |
| `reliable_talent` | — | Test d'une compétence maîtrisée : un d20 de 9 ou moins compte comme 10 |
| `relentless_endurance` | — | Tombe à 1 PV au lieu de 0, tant qu'il reste la ressource `relentless_endurance` |
| `critical_range` | `amount` | Critique à partir de 20 − amount (Champion) |
| `save_advantage` | `id` | Avantage aux sauvegardes d'un attribut |
| `initiative_proficiency`, `initiative_advantage` | — | Bonus de maîtrise / avantage à l'initiative |
| `skill_advantage` | `id` | Avantage aux tests d'une compétence |
| `spellcasting_ability` | `id` | Attribut d'incantation hors classe (Initié à la magie) |
| `savage_attacker` | — | Une fois par tour, dés de dégâts d'arme lancés deux fois, le meilleur gardé |
| `ignore_resistance` | `damage_type` | Les cibles ne résistent plus à ce type |
| `ranged_attack`, `armored_ac`, `dueling` | `amount` | Styles Archerie (toucher à distance), Défense (CA en armure), Duel (dégâts à une main) |
| `great_weapon_fighting` | — | À deux mains, 1 et 2 aux dés de dégâts comptent 3 |
| `armor_strength_reduction` | `amount` | Force conseillée des armures réduite |
| `potent_cantrip`, `empowered_evocation` | — | Évocateur : tour de magie raté = moitié des dégâts ; + attribut aux dégâts d'évocation (effets `"school": "evocation"`) |
| `fast_hands`, `survivor` | — | Voleur : un objet par tour sans coût d'action ; Champion : regain de PV à moitié de vie |

### Équipement (`equipment.json`)

| Catégorie | Champs |
|---|---|
| `weapon` | `damage`, `damage_type`, `properties` (`finesse`, `light`, `thrown`, `versatile`, `heavy`, `two_handed`, `ranged`), `versatile_damage` pour une arme polyvalente |
| `armor` | `armor_type` (`clothing` et `light` : base + DEX, `medium` : base + DEX max 2, `heavy` : base seule), `base_ac`, `strength`? (Force requise, voir ci-dessous) |
| `shield` | `ac_bonus` |
| `accessory` | `slot` : `head` (couvre-chef), `hands` (gants), `legs` (jambes), `feet` (chaussures), `neck` (collier) ou `ring` (anneau : `ring_1`, ou `ring_2` si le premier est pris) |

Champs communs : `weight` (kg) ; facultatifs : `modifiers`, `rarity` (`common`, `uncommon`, `rare`, `very_rare`,
`legendary`, qui donne la couleur du nom), `value` (prix en po), `description`.

**Objets magiques** : ce sont des équipements avec des `modifiers`. Par exemple, une épée +1 porte
`[{"type": "weapon_attack", "amount": 1}, {"type": "weapon_damage", "amount": 1}]`, et l'Anneau de protection
`[{"type": "ac", "amount": 1}, {"type": "saving_throws", "amount": 1}]`.

**Emplacements** (`Equipment.SLOTS`) : `main_hand`, `off_hand`, `head`, `armor` (torse), `hands`, `legs`, `feet`,
`neck`, `ring_1`, `ring_2`. Les anciennes sauvegardes sont converties (`amulet` → `neck`, `ring` → `ring_1`).

### Sac et inventaire

- Le **sac du groupe** est l'inventaire du héros (`character.inventory`, `{id: quantité}`). Il mélange objets et
  équipement ; l'API `Items` donne nom, description, rareté, valeur et résumé de n'importe quel id.
- Les compagnons s'équipent en y puisant, et ce qu'ils retirent y retourne (`LifeState.equip`, `unequip`,
  `use_item`, `drop_item`). Il n'y a pas de restriction de maîtrise d'armure pour l'instant.
- Hors combat, seuls les objets de soins sont utilisables. L'Antidote ne sert qu'en combat.
- **Écran** : bouton « Inventaire (I) » sous la fiche (hors combat), avec l'équipement du membre choisi à gauche et le
  sac à droite (Équiper, Retirer, Utiliser, Jeter), des filtres par catégorie, une recherche et la charge du groupe.
- **Objets de quête** (`"quest": true` dans `items.json`) : ni vendus ni jetés.
- **Butin** : les créatures peuvent lâcher de l'équipement (`loot`), comme le brigand (dague, épée courte, cuir
  clouté) ou l'Alpha (Anneau de protection). L'effet `equip` range l'objet remplacé dans le sac.

**Règles appliquées :**
- Une arme de finesse utilise le meilleur de FOR et DEX, une arme à distance utilise la DEX.
- Une arme polyvalente tenue sans bouclier fait ses dégâts à deux mains.
- Une arme à deux mains et un bouclier s'excluent.
- L'entrée `unarmed` (mains nues) est obligatoire.
- **Force et encombrement** (`rules.json › encumbrance`) : toute armure peut être portée. Le malus d'encombrement
  s'applique à **tous les jets de FOR et de DEX** (attaques, sauvegardes, tests de compétence et d'attribut,
  initiative, fuite). Il cumule, avec un maximum de `max_penalty` (5) :
  - l'**armure** : chaque type a une Force conseillée (`armor_strength` : vêtements 0, légère 10, intermédiaire 12,
    lourde 14 ; un objet peut la redéfinir avec `strength`) ; −1 par tranche de `armor_points_per_penalty` (2)
    points de Force manquants ;
  - la **charge** : le groupe porte le sac et tout son équipement ; sa capacité est la somme de
    `carry_per_strength` (7,5 kg) × Force de chaque membre ; au-delà, −1 par tranche de
    `overload_percent_per_penalty` (10) % de surcharge, pour tout le groupe (`LifeState.refresh_load`).
  La fiche, l'inventaire (charge / capacité) et le combat en tiennent compte.

### Défenses

Chaque personnage a ses défenses propres, accordées par des événements (`add_defense`). S'y ajoutent celles de
l'espèce, des dons et de l'équipement : `Character.all_defenses()` les réunit. Les ennemis déclarent les leurs dans
`defenses`.

**État associé à un type** : `damage_types.json › status` (`{"id": "burning", "chance": 0.25, "stacks": 1}` pour
le feu). À chaque fois que ce type blesse, la cible a cette chance de recevoir l'état, sauf immunité. Les dégâts des
états eux-mêmes ne le déclenchent pas.

Calcul des dégâts subis :
- immunité : 0 ;
- résistance : moitié, arrondie à l'inférieur ;
- vulnérabilité : double ;
- résistance et vulnérabilité au même type s'annulent.

## Tailles, points de vie, inconscience

- **Tailles** (`rules.json › sizes`) : échelle de −4 à 5 (`species.json › size`, `creatures.json › size`). Places au
  combat (`combat › size_slots`) et taille des sprites (`combat › sprite_scale`) par valeur ; condition d'événement
  `{"type": "size", "in": [-1]}` ou `{"type": "size", "max": -1}`.
- **PV max** (`rules.json › hit_points`) : Constitution × `size_base` (1,4142)^taille, au moins 1, + modificateurs
  (`hp_per_level` × niveau, don Robuste). Ni la classe ni le niveau ne les augmentent. Les créatures gardent leurs PV
  en dés.
- **Inconscience** : en combat, un membre du groupe à 0 PV est inconscient tant qu'un autre tient debout ; après une
  victoire ou une fuite, il revient à 1 PV. Si tout le groupe tombe dans un combat mortel, le héros et les
  compagnons meurent.

## Économie d'actions et réactions

- Par tour : une **action** et une **action bonus** (`"bonus": true` dans actions.json ; Se cacher devient bonus avec
  la Ruse, modificateur `cunning_action`) ; `"free": true` ne coûte rien (Fougue). « Fin du tour » à tout moment.
- **Réactions** : les actions gardées à la fin du tour (action, action bonus) donnent autant de réactions jusqu'au
  tour suivant. Une attaque qui touche (sauf 20 naturel) peut être **esquivée** (Physique, DEX) puis **parée**
  (Physique ou Armes de mêlée, DEX ; une attaque à distance ou un sort ne se pare qu'avec un bouclier) : elle ne
  touche que si son total dépasse le jet de défense. Automatique pour l'instant.
- **IA par personnage** : `Character.auto_combat` (bouton « IA : oui/non » dans la barre d'actions).

## Repos et multiclassage

- **Repos** (`locations.json › rest`) : `{"type": camp | inn | home, "name", "cost"?, "event_chance"?}`. Le bouton
  de la fiche (R) se repose au dernier lieu visité (`LifeState.location`) : repos long de tout le groupe jusqu'au
  matin ; l'auberge coûte de l'or ; un camp peut tirer un événement nocturne.
- **Multiclassage** : `Character.class_levels` (classe -> niveau) ; `pending_class_levels` (niveaux gagnés dont la
  classe est à choisir au hub, `assign_class_level`). Les aptitudes, améliorations et dés d'Attaque sournoise
  (`scaling.class`) suivent le niveau de classe ; les tours de magie suivent le niveau total ; les emplacements de
  sort se cumulent. Clés de choix des classes secondaires : `feature:<classe>:<aptitude>/<choix>`.

## Économie : boutiques, fabrication, forge

### Boutiques (`shops.json`)

| Champ | Description |
|---|---|
| `location` | Lieu où elle se trouve. Un lieu qui a des boutiques ouvre un **menu** (se promener = événement au hasard, entrer dans une boutique, retour) au lieu de tirer directement un événement. Entrer dans une boutique ne fait pas passer le temps |
| `stock` | `{id: quantité}`, reconstitué tous les `restock_days` jours. Ce que le joueur vend rejoint le stock |
| `price_rate` | Multiplicateur des prix d'achat (1.0) |
| `crafting`? | Station de fabrication (`forge`, `alchemy`) : recettes de `recipes.json` |
| `upgrade`? | `true` : la boutique améliore armes, armures et boucliers |

L'état des boutiques (stock, jour du dernier réassort) est sauvegardé avec la vie (`LifeState.shops`).

### Prix (`rules.json › trade`)

- Achat : valeur × `price_rate` × (1 − remise), au moins 1 po.
- Revente : valeur × `sell_rate` (0,5) × (1 + remise), au moins 1 po si l'objet a de la valeur.
- Remise : `percent_per_point` (3) % par point de `price_skill` (Persuasion) du **meilleur négociateur du groupe**,
  entre −`max_percent` et +`max_percent` (15 %). Elle joue sur l'achat comme sur la revente.
- **Tout marchand rachète tout** ce qui a de la valeur, sauf les objets de quête.

### Recettes (`recipes.json`)

`{"id", "result", "count"? (1), "station": "forge" | "alchemy", "materials": {id: quantité}, "gold"? (0), "dc"? (10)}`.
Les matériaux et l'or sont pris dans le sac du groupe. **Test** (`rules.json › crafting`) : la compétence de la
station (Artisanat avec la DEX à la forge, Potions et cuisine à l'alchimie) contre le DD ; un échec gâche
`failure_loss` (la moitié) des matériaux et l'or. Après `profession_threshold` objets à une station, la fiche
affiche le **métier** qui se dessine (« Forgeronne (7 objets) »).

### Amélioration (`rules.json › forge`)

- Une arme, une armure (pas un vêtement) ou un bouclier **ordinaire** (sans rareté) devient +1, +2, +3 pour
  `upgrade_costs` po (50, 150, 400), avec la rareté `upgrade_rarities`.
- L'objet amélioré a l'id `<base>@<rang>` (ex. `longsword@2`). `Equipment.def` le calcule à partir de la base : nom
  « Épée longue +2 », bonus au toucher et aux dégâts (arme) ou à la CA, valeur augmentée. Il se sauvegarde,
  s'équipe et se revend comme n'importe quel objet.
- On peut améliorer un objet du sac ou un objet porté par un membre du groupe.

Les API correspondantes sont `Shops` (boutiques et prix), `Crafting` (recettes et amélioration) et `Items`
(objets du sac, avec leur `category`).

## Social : PNJ, relations, monde autonome

Le détail de conception est dans [social.md](social.md). Données : `npc_roles.json`, `traits.json`,
`npc_facts.json`, `social_actions.json`, `rules.json › social`. API : `Social` ; modèle : `Npc`.

| Fichier | Contenu |
|---|---|
| `npc_roles.json` | `{"id", "name", "location", "regular"? (habitué créé à la première visite), "searchable"? (on peut le chercher), "fixed"? ({name, species, gender, age}), "shop"? (sa boutique), "class"? (recrutable), "inventory"?, "gold"? (dés), "foreign_chance"?, "art"}` |
| `traits.json` | `{"id", "name", "description", "hidden"?, "reactions": {action: {"dc"?, "gain"?}}, "refuses"?: [actions], "likes"?: [catégories], "jealousy"?}` |
| `npc_facts.json` | `{"id", "name", "values": [textes avec {npc}, {g:…}], "creates_relative"?}` |
| `social_actions.json` | `{"id", "name", "category": friendly \| romantic \| hostile \| special, "requires"? ({friendship, love, trust, status, not_status}), "check"? ({skill, ability?, dc \| vs}), "romantic"?, "special"? (reveal_fact, trade, recruit, gestures, child, break_up), "success"/"failure" ({friendship, love, trust, reputation, set, fear}), "lines"}` |

- **Monde** (`Meta`, sauvegardé avec la méta) : `npcs` (id -> `Npc`), `world_day` (horloge du monde, toutes vies
  confondues), `pregnancies`, `next_npc_id`. Chaque nouveau jour : `Social.daily_tick` (liens et couples entre PNJ,
  rumeurs, naissances).
- **Relation avec le héros** : `Npc.player` (`met`, `friendship`, `love`, `trust`, `status`, `open`, `fear`), remise à
  zéro à chaque nouvelle vie ; les souvenirs (`memories`) restent.
- **Vie** (`LifeState`) : `reputation` par lieu.
- **Événements** : un choix (ou son issue) peut porter `"approval": {"mira": 2}` (approbation des compagnons) ;
  effets `{"type": "npc_relation", "npc", "friendship"?, "love"?, "trust"?}` et `{"type": "reputation", "amount",
  "location"?}` ; condition `{"type": "reputation", "location", "min"?, "max"?}`.
- **Activités** : une action sociale peut coûter de l'or (`gold`) et du temps en plus (`extra_time`).
- **Initiatives** (`rules.json › social › initiative_chance`, `neglect_days`) : au hub, un PNJ connu vient parfois
  (une fois par jour au plus) : un ami demande un service, un rival provoque, un partenaire délaissé se plaint.
- **Réputation** : à la première rencontre, Amitié + réputation ÷ 4 ; prix +5 % (respecté) ou −10 % (honni).
- **Interface** : « Parler à quelqu'un » dans le menu d'un lieu, fenêtres `SocialView` (dialogue), `NpcTradeView`
  (échange), `CarnetView` (carnet, touche C). Quitter une conversation après une action fait passer un créneau
  (`Game.end_interaction`).

## Flags : conventions

- **Flags de vie** (`set_flag`) : l'état de l'histoire du personnage actuel. Par exemple `quest_herbs_accepted` ou
  `knows_shrine_rune`.
- **Flags de monde** (`set_world_flag`) : les conséquences durables. Par exemple `ysolde_friend` ou `shrine_awakened`.
- Pour une quête, on pose un flag `<quête>_accepted` au départ, puis `<quête>_done` à la fin. Les événements suivants
  utilisent `flag` et `not` → `flag`.

## Compétences (`skills.json`) et rangs

```json
{"id": "physique", "name": "Physique", "category": "combat", "instinctive": true, "abilities": ["str", "dex", "con"]}
```

| Champ | Description |
|---|---|
| `category` | `combat`, `social`, `roguery` (Roublardise), `knowledge` (Connaissances et métiers) |
| `abilities` | Attributs utilisables ; un test sans attribut imposé prend le meilleur (encombrement compris) |
| `instinctive` | Rang de départ 2 au lieu de 1 |
| `base_rank`, `caster_base_rank` | Rang de départ particulier (Magie : 0, ou 2 pour un lanceur de sorts) |

- **Rang** = départ + 1 par passé qui donne la compétence + `classes.json › skill_ranks` + modificateurs
  `skill_rank` (choix de classe, dons, Expertise, objets). Bonus d'un test = attribut + rang.
- **Attaques** : attribut + rang de la compétence de l'arme (`Equipment.skills_for` : `skill` de l'arme, sinon
  Armes de trait pour une arme à distance, Armes de mêlée sinon ; mains nues : le meilleur avec Physique). Sorts :
  attribut d'incantation + rang de Magie ; DD des sorts = 8 + rang de Magie + attribut.
- **Jets de sauvegarde** (provisoire) : attribut + rang (1, +1 si la classe le maîtrise, +1 par `save_proficiency`).
- **Tests d'événement** : `{"skill": "persuasion", "ability"?: "str", "dc": 12}`. Option du joueur
  (`Meta.settings.manual_skill_ability`) : de petits boutons par attribut à côté du choix.
- **Créatures** : `"skills": {"stealth": 2}` (rang 0 si absente).
- **Anciennes compétences** (Athlétisme, Arcanes…) : traduites automatiquement (`Skills.ALIASES`).
- **Langues** (`rules.json › languages`) : le Commun est connu de tous ; une langue à choisir par rang de Langues
  (choix `skill/languages`, au hub).
- **Conditions** : `{"type": "passive", "skill": "perception", "min": 13}` (10 + bonus).
- **Actions communes** (`rules.json › common_actions`) : Se cacher, Intimider, Premiers soins, pour tous les
  personnages ; elles reposent sur l'effet de combat `check` (test de compétence contre un DD ou contre une
  sauvegarde de la cible ; raté, les effets suivants sont ignorés).

## Choix du personnage (`choices`)

Une espèce, une classe, une aptitude (y compris de sous-classe) ou un don peut déclarer des **choix** à faire
(API `Choices`) :

```json
{"id": "skills", "name": "Compétences de classe", "type": "skill", "count": 2, "at_creation": true,
 "options": ["physique", "perception", "survival"], "modifiers": [{"type": "skill_rank", "id": "$", "amount": 1}],
 "default": ["physique", "perception"]}
```

| Champ | Description |
|---|---|
| `type` | `skill`, `ability`, `damage_type`, `feat` (avec `category`), `action` (avec `cost`? : ressource à la place d'un emplacement), `option` |
| `count` | Nombre de valeurs à choisir (1) ; `allow_repeat` : la même valeur peut être prise plusieurs fois |
| `options` | Valeurs proposées (toutes par défaut) ; pour `option`, des objets `{"id", "name", "description", "modifiers"?, "actions"?, "features"?}` |
| `modifiers` | Modèles de modificateurs, `"$"` étant remplacé par la valeur choisie |
| `from` | `proficient` : seulement des compétences déjà maîtrisées (Expertise) |
| `default` | Valeurs prises d'office : pour les choix de création non faits, et pour les compagnons |
| `at_creation` | Proposé à l'écran de création ; sinon, au hub, dès que le choix existe |

- Les valeurs choisies sont sauvegardées dans `Character.choices` (clé « source/id », ex. `class/skills`,
  `species/ancestry`, `feature:subclass/subclass`, `feat:skilled/skills`).
- Une **sous-classe** est une option dont les `features` (aptitudes par niveau) s'ajoutent à celles de la classe.
- Un **don** choisi (type `feat`) est acquis ; ses propres choix deviennent à leur tour des choix en attente.
- Les compétences de classe ne sont plus fixes : la classe propose sa liste (champ `skills` supprimé).
- Un don peut aussi accorder des `actions` et des `resources` (rechargées par un repos long). Une action
  « `sleep|magic_initiate` » est le sort Sommeil payé avec la ressource `magic_initiate`.

## Espèces, classes et passés

- `locked: true` : l'espèce ou la classe n'est pas jouable tant qu'un effet `unlock` ne l'a pas débloquée.
  `unlock_hint` est l'indice affiché à l'écran de création.
- **Espèce** : elle n'a **aucune influence sur les attributs**. Elle définit les champs suivants :
  - `size` : la catégorie de taille (`tiny`, `small`, `medium`, `large`), utilisable dans les conditions ;
  - `start_age` : l'âge au début de la partie, au moins `rules.json › majority_age` (18), comme l'étape `adult` ;
  - `age_stages` : l'âge de début de chaque étape de vie (conditions `life_stage`, portrait) ;
  - `aging_age` : l'âge limite au-delà duquel le personnage vieillit (voir plus bas) ;
  - `modifiers`? : ses traits (résistances, immunités, `relentless_endurance`…) ;
  - `resources`? : ressources rechargées par un repos long (ex. `{"relentless_endurance": 1}` pour l'orc) ;
  - `bonus_feats`? : dons en plus à choisir au début de la partie (1 pour l'humain).
- **Classe** : `hit_die` (dé de vie), `saving_throws`, `choices` (dont les compétences de classe) et `features`
  (aptitudes par niveau, dont la sous-classe). `ability_priority` donne le **modèle
  d'attributs** proposé : la répartition standard (15, 14, 13, 12, 10, 8) dans cet ordre, puis +2 sur le premier
  attribut et +1 sur le second.
- **Passé** : `skills`, soit 2 compétences maîtrisées qui s'ajoutent à celles de la classe, et `feat`, le don accordé.
  Champs facultatifs : `gold` (or en plus au départ) et `start_items`.
- `art` : les paramètres du portrait procédural. Pour une espèce : `ears` (`round`, `goblin`, `elf`), des listes de
  couleurs `skin`, `hair` et `eyes`, et en option `beard_chance` (probabilité d'une barbe), `tusks` (défenses),
  `horns` et `horn_color` (cornes). Pour une classe : `headgear` (`helmet`, `wizard_hat`, `hood`), `outfit` et
  `accent`.

## Attributs : achat de points

Le système est le même que dans Baldur's Gate 3. Il se règle dans `rules.json › point_buy` :

- chaque attribut part de `min` (8) et peut monter jusqu'à `max` (15) ;
- le joueur dispose de `budget` points (27), dépensés selon le barème `costs` : 9 → 1, … 13 → 5, 14 → 7, 15 → 9 ;
- `bonuses` ([2, 1]) : un +2 et un +1 à placer sur deux attributs différents.

## Vieillesse

Au-delà de `aging_age` (l'âge limite de l'espèce), chaque nouvelle année retire 1 à un attribut tiré au hasard, et le
joueur en est prévenu. Quand un attribut tombe à 0, quelle qu'en soit la raison, le personnage meurt.

## Genre

Le genre (`rules.json › genders`) n'a aucun effet sur l'apparence ni sur les règles. Il sert uniquement aux accords
dans les textes, avec la syntaxe `{g:masculin|féminin|neutre}` :

```
"Vous êtes {g:prêt|prête|prêt·e} à partir."
```

## Images

`ArtProvider` cherche d'abord une image définitive, puis génère un placeholder pixel art à défaut :

| Image | Fichier attendu |
|---|---|
| Portrait | `res://assets/portraits/<espèce>_<classe>_<étape>.png` (ex. `goblin_wizard_adult.png`) |
| Illustration d'événement | `res://assets/events/<id_événement>.png` |
| Illustration de lieu | `res://assets/locations/<id_lieu>.png` |

## Localisation

Les textes du JSON sont en français. Leur clé de traduction est dérivée des ids :

- `evt.<id>.title` et `evt.<id>.text` pour l'événement ;
- `evt.<id>.<choix>.text` pour le texte d'un choix ;
- `evt.<id>.<choix>.<outcome|success|failure>` pour le texte d'un résultat.

Quand une traduction existe pour la langue courante, elle remplace le texte du JSON. Les textes d'interface passent par
`tr()`, avec la phrase française comme clé.

## Creator Points (méta-progression)

Les Creator Points se règlent dans `rules.json › creator_points`, et l'API correspondante est `CreatorPoints`.
**Toutes les valeurs sont provisoires**, en attendant les retours des testeurs.

- **Gain** : à la mort, `xp_per_point` (100) XP gagnées par le héros valent 1 point, avec au moins `min_per_life` (1)
  point par vie. Le gain est noté dans la chronique.
- **Bonus pour la vie suivante** (`upgrades`) : ils s'achètent dans l'onglet « Creator Points » de la création et sont
  dépensés au lancement de l'aventure.

| type | Effet |
|---|---|
| `point_buy` | Points en plus pour l'achat des attributs |
| `level` | Niveaux de départ en plus. Les améliorations des niveaux franchis (attribut, don) se choisissent en jeu |
| `gold` | Or en plus au départ |

  Chaque bonus a un `cost` (un nombre, ou une liste avec un coût par rang) et un `max` (nombre de rangs).
- **Déblocages définitifs** : une espèce ou une classe verrouillée qui a un `unlock_cost` s'achète dans le même onglet.
  Les points sont dépensés immédiatement.

## Sauvegarde

L'autoload `Saves` (`scripts/core/save_manager.gd`) gère deux fichiers JSON dans `user://`. Sur Windows, ce dossier
est `%APPDATA%/Godot/app_userdata/Lifantasy/` ; sur le Web, les données vont dans le stockage du navigateur.

| Fichier | Contenu |
|---|---|
| `meta.json` | Ce qui survit à la mort : flags du monde, déblocages, événements déjà vus, chronique des vies |
| `life.json` | La vie en cours : personnage, compagnons, temps, flags, hasard (graine et état), combat en attente. Supprimé à la mort |

**Quand la partie est-elle sauvegardée ?** Automatiquement :
- au début d'une vie ;
- à chaque retour au hub ;
- après chaque choix ;
- à la fin de chaque combat ;
- à la mort ;
- avec Échap (retour au menu) et à la fermeture de la fenêtre.

**Anti-triche :** un combat déclenché est noté comme « en attente » (`pending_combat`) et reprend au chargement.
Quitter le jeu ne permet donc pas de l'esquiver, mais il recommence depuis le début.

**Format :** chaque fichier est `{"version": N, "data": …}`. Une sauvegarde d'une autre version est ignorée. Si le
format change, il faudra augmenter `Saves.VERSION` et prévoir une conversion.

**Écran titre** (`scenes/title.tscn`, scène de démarrage) : Continuer, Nouvelle vie, Chronique des vies passées,
Nouveau monde (efface tout, avec confirmation), Quitter.

## Outils

Toutes les commandes se lancent depuis le dossier `claude_rpg/`, avec `godot` désignant l'exécutable console de Godot
4.4 :

```sh
# Tests automatisés : validation des données, règles, simulation de 1500 actions
godot --headless --path . res://tests/test_runner.tscn

# Équilibrage des combats (taux de victoire par classe et par rencontre)
godot --headless --path . res://tools/combat_bench.tscn

# Planches PNG de tous les portraits et décors procéduraux
godot --headless --path . res://tools/art_preview.tscn -- <dossier>

# Captures d'écran du jeu (ouvre une fenêtre)
godot --path . res://tools/screenshot.tscn -- <dossier>
```

> **Export :** les `.json` ne sont pas des ressources Godot. Dans chaque preset d'export, il faudra ajouter `*.json` aux
> filtres « Fichiers non-ressources à inclure ».
