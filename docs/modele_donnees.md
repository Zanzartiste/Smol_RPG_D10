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
| `items.json` | Objets (`use` : utilisable en combat, ex. `{"heal": "2d4+2"}`) |
| `enemies.json` | Ennemis : CA, PV, attaques, XP, butin, apparence |
| `actions.json` | Actions de combat des classes (attaques, sorts, soins) |
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
| `check` | Test d20 : `{"skill": "<compétence>", "dc": N}` ou `{"ability": "<attribut>", "dc": N}` |
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
| `add_item` / `remove_item` | `id`, `count`? (1) | Ajoute ou retire des objets |
| `goto` | `event` | Enchaîne directement sur un autre événement, après le bouton « Continuer » |
| `pass_time` | `slots`?, `days`? | Fait passer du temps en plus |
| `die` | `cause`? | Tue le personnage |
| `long_rest` | — | Repos long : PV et ressources (emplacements de sort) du groupe au maximum |
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
| `enemies` | Ids d'`enemies.json`. Les doublons sont numérotés (Brigand A, Brigand B) |
| `flee` (true), `flee_dc` (12) | La fuite est-elle possible, et son DD (d20 + DEX) |
| `on_defeat` | `death` (par défaut) : le héros à 0 PV meurt, les compagnons à 0 PV aussi. `knockout` : tout le monde se relève à 1 PV, comme pour une bagarre de taverne |
| `victory` / `fled` / `defeat` | Texte et effets de chaque issue. `defeat` ne sert qu'en `knockout` |

**Déroulement :**
- **Initiative** : chacun lance d20 + DEX, puis le groupe et les ennemis agissent dans cet ordre.
- **Attaque** : d20 + bonus contre la CA de la cible. Un 20 naturel est un critique (dés de dégâts doublés), un 1 naturel
  rate toujours.
- **Bonus d'attaque d'un allié** : le modificateur de l'attribut, plus la maîtrise.
- **Récompenses à la victoire** : l'XP de tous les ennemis va à chaque membre du groupe encore debout, et l'or et le
  butin s'ajoutent.

**Équilibrage :** `tools/combat_bench.tscn` joue chaque rencontre des centaines de fois et affiche le taux de victoire,
par classe, en solo et avec un compagnon.

### Ennemis (`enemies.json`)

| Champ | Description |
|---|---|
| `ac`, `hp` | Classe d'armure, et PV sous forme d'expression de dés (`2d6+2`), tirés à chaque combat |
| `abilities` | Attributs (la DEX sert à l'initiative) |
| `attacks` | `[{"name", "to_hit", "damage", "damage_type"}]`, ou `[{"name", "to_hit", "weapon": "scimitar", "damage_bonus"?}]` pour reprendre une arme du catalogue. L'ennemi choisit une attaque au hasard et vise un membre du groupe au hasard |
| `defenses` | Résistances, immunités et vulnérabilités : `{"resistances": ["slashing"], "immunities": [], "vulnerabilities": [], "status_immunities": []}` |
| `size` | Taille (`small`, `medium`, `large`…), qui détermine la taille du sprite |
| `xp`, `gold`?, `loot`? | Récompenses. `loot` : `[{"item", "chance", "count"?}]` |
| `death_cause` | Texte de l'écran de mort si l'ennemi tue le héros |
| `art` | Placeholder : `{"type": "wolf" \| "rat" \| "humanoid", …}` |

### Actions de combat (`actions.json`)

| Champ | Description |
|---|---|
| `type` | `attack` (jet contre la CA), `auto` (touche toujours) ou `heal` |
| `target` | `enemy`, `ally` ou `self` |
| `ability` | `weapon` (attribut de l'arme), `spell` (attribut d'incantation de la classe) ou un id d'attribut |
| `damage` | Expression de dés, ou `weapon` pour les dégâts de l'arme. `add_mod` : ajoute le modificateur. `extra_damage` : dés en plus |
| `damage_type` | Type de dégâts (`fire`, `force`…), ou `weapon` pour celui de l'arme |
| `heal` | Expression de soins (`level` = niveau du personnage) |
| `per_combat` | Nombre d'utilisations par combat |
| `cost` | Ressource consommée (ex. `spell_slot`), rechargée par `long_rest` |

Les classes déclarent `equipment` (`{"main_hand": "longsword", "armor": "chain_mail", "off_hand": "shield"}`, ids de
`equipment.json`), `actions`, et selon le cas
`spellcasting` (attribut) et `resources` (ex. `{"spell_slot": 2}`).

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
| `StatusEffects` | `status_effects.json` | `ids()`, `name_of(id)` |
| `Modifiers` | — | `sum(...)`, `grants(...)`, `defenses(...)`, `describe(...)` : interprète les modificateurs |
| `Defenses` | — | `from_dict()`, `to_dict()`, `add()`, `remove()`, `has()`, `merge()`, `describe()` |

### Dons (`feats.json`)

```json
{
	"id": "athlete",
	"name": "Athlète",
	"description": "…",
	"prerequisites": [{"type": "ability", "id": "dex", "min": 13}],
	"modifiers": [{"type": "ability", "id": "str", "amount": 1}, {"type": "skill_proficiency", "id": "athletics"}]
}
```

Les prérequis s'écrivent comme les conditions des événements. Un personnage obtient un don avec l'effet `add_feat`, et
un compagnon peut en avoir dans `companions.json` (`feats`).

### Modificateurs

Les dons, les espèces et les équipements peuvent porter des `modifiers`. Ils s'appliquent automatiquement au personnage.

| type | Champs | Effet |
|---|---|---|
| `ability` | `id`, `amount` | Bonus d'attribut. **Interdit pour une espèce** |
| `skill_proficiency` | `id` | Maîtrise d'une compétence |
| `hp_per_level` | `amount` | PV max en plus, à chaque niveau |
| `initiative` | `amount` | Bonus d'initiative |
| `ac` | `amount` | Bonus de CA |
| `resistance` / `immunity` / `vulnerability` | `damage_type` | Défense contre un type de dégâts |
| `status_immunity` | `status` | Immunité à un état |

### Équipement (`equipment.json`)

| Catégorie | Champs |
|---|---|
| `weapon` | `damage`, `damage_type`, `properties` (`finesse`, `light`, `thrown`, `versatile`, `heavy`, `two_handed`, `ranged`), `versatile_damage` pour une arme polyvalente |
| `armor` | `armor_type` (`light` : base + DEX, `medium` : base + DEX max 2, `heavy` : base seule), `base_ac` |
| `shield` | `ac_bonus` |

Tout équipement peut aussi porter des `modifiers`, par exemple une cape qui donne une résistance au feu.

**Règles appliquées :**
- Une arme de finesse utilise le meilleur de FOR et DEX, une arme à distance utilise la DEX.
- Une arme polyvalente tenue sans bouclier fait ses dégâts à deux mains.
- Une arme à deux mains et un bouclier s'excluent.
- L'entrée `unarmed` (mains nues) est obligatoire.

### Défenses

Chaque personnage a ses défenses propres, accordées par des événements (`add_defense`). S'y ajoutent celles de
l'espèce, des dons et de l'équipement : `Character.all_defenses()` les réunit. Les ennemis déclarent les leurs dans
`defenses`.

Calcul des dégâts subis :
- immunité : 0 ;
- résistance : moitié, arrondie à l'inférieur ;
- vulnérabilité : double ;
- résistance et vulnérabilité au même type s'annulent.

## Flags : conventions

- **Flags de vie** (`set_flag`) : l'état de l'histoire du personnage actuel. Par exemple `quest_herbs_accepted` ou
  `knows_shrine_rune`.
- **Flags de monde** (`set_world_flag`) : les conséquences durables. Par exemple `ysolde_friend` ou `shrine_awakened`.
- Pour une quête, on pose un flag `<quête>_accepted` au départ, puis `<quête>_done` à la fin. Les événements suivants
  utilisent `flag` et `not` → `flag`.

## Espèces, classes et passés

- `locked: true` : l'espèce ou la classe n'est pas jouable tant qu'un effet `unlock` ne l'a pas débloquée.
  `unlock_hint` est l'indice affiché à l'écran de création.
- **Espèce** : elle n'a **aucune influence sur les attributs**. Elle définit les champs suivants :
  - `size` : la catégorie de taille (`tiny`, `small`, `medium`, `large`), utilisable dans les conditions ;
  - `start_age` : l'âge au début de la partie ;
  - `age_stages` : l'âge de début de chaque étape de vie (conditions `life_stage`, portrait) ;
  - `aging_age` : l'âge limite au-delà duquel le personnage vieillit (voir plus bas).
- **Classe** : `hit_die` (dé de vie) et `skills` (compétences maîtrisées). `ability_priority` donne le **modèle
  d'attributs** proposé : la répartition standard (15, 14, 13, 12, 10, 8) dans cet ordre, puis +2 sur le premier
  attribut et +1 sur le second.
- **Passé** : `skills`, soit 2 compétences maîtrisées qui s'ajoutent à celles de la classe. Champs facultatifs : `gold`
  (or en plus au départ) et `start_items`.
- `art` : les paramètres du portrait procédural. Pour une espèce : `ears` (`round`, `goblin`, `elf`) et des listes de
  couleurs `skin`, `hair` et `eyes`. Pour une classe : `headgear` (`helmet`, `wizard_hat`, `hood`), `outfit` et
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
