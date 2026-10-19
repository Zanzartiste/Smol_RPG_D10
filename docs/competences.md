# Catalogue des compétences — Lifantasy

> Document de conception : il recense les compétences qui doivent exister dans le jeu, avant leur saisie dans
> `claude_rpg/data/skills.json`. Les champs techniques sont détaillés dans [modele_donnees.md](modele_donnees.md).

## Règles générales

- Une compétence dépend généralement d'**un attribut** , mais souvent peut être utilisée avec d'autres attributs dans certains contextes précis. Elle a un Rang qui lui est propre et témoigne de l'expertise ou non d'une créature dans cette compétence. Les compétences dites "instinctives" commencent avec un rang de 2, les autres ont un rang de 1.
- **Test** (système d10, voir [systeme_de_jeu.md](systeme_de_jeu.md)) : [rang de la compétence] d10 contre un
  seuil égal à l'attribut ; chaque dé ≤ seuil est un succès (9 et 10 jamais, 1 toujours et relancé) ; réussi si
  les succès atteignent la difficulté (1 à 8+).
- **Rangs de départ** : 1, ou 2 pour une compétence instinctive.
- **Rangs en plus** (implémenté) : le passé (4 rangs, 1 par compétence), la classe (8 rangs, 2 au plus par compétence, voir [classes.md](classes.md) et le
  tableur `Classes.ods`, feuille 2), 8 rangs libres à la création (environ 20 rangs en tout), les dons (Doué, Athlète…), l'Expertise du
  Roublard, certains objets (Bottes et Cape elfiques).
- **Plafond de création** : aucune compétence ne dépasse 5 à la création, rang de départ, passé et classe compris :
  instinctive 2 + passé 1 + classe 2 = 5 au plus (le validateur vérifie 1 rang par compétence pour un passé, 2 pour
  une classe). Les rangs libres ne poussent pas au-delà de 5 ; les dons et objets peuvent ensuite le faire.
- **Gagner des rangs en montant de niveau** (implémenté) : un rang dans une compétence au choix tous les deux
  niveaux (2, 4, 6… 20), un rang au plus par compétence et par niveau, sans plafond.
- **Sorts** : il n'y a plus de compétence Magie. Chaque famille de magie a sa compétence d'incantation : arcanique
  → Érudition, divine → Détermination, primale → Nature, artistique → Arts. Elle sert aux attaques de sort et aux
  sorts que la cible doit repousser, contre l'attribut d'incantation.

- **Résister** (ex-jets de sauvegarde) : chaque effet ou altération demande un test de compétence, le plus souvent
  Physique pour les effets physiques (poisons…) et Détermination pour les effets mentaux (peur, sommeil, charme…).
  Détail technique dans [systeme_de_jeu.md](systeme_de_jeu.md). Pas de maîtrise de classe ; le don Résistant donne un dé
  de plus pour un attribut.

- Lorsque plusieurs attributs peuvent être utilisés dans une même situation, on prend le plus élevé par défaut automatiquement. Dans le menu des options, on doit pouvoir cocher un paramètre qui permet de faire ce choix manuellement (si on souhaite pour des raisons de flavor utiliser une stat inférieure lors d'un jet par exemple)
  → **Implémenté** : option « Choisir soi-même l'attribut des tests de compétence » (écran titre › Options). Le
  bouton du choix lance le test avec le meilleur attribut, et de petits boutons accolés (« SAG 55 % », « DEX 45 % »)
  le lancent avec l'attribut choisi. Quand le test impose un attribut (intimider : Persuasion avec la FOR), il n'y
  a pas de choix.
- **Créatures** : elles ont des rangs elles aussi (`skills` dans le bestiaire) ; une compétence non listée est au
  rang 0.

---

## Modèle de fiche (à copier)

```markdown
### <Nom> (`<id>`) (instinctive ?)

- **Décrit** : …
- **Attribut** : FOR / DEX / CON / INT / SAG / CHA (plusieurs possibles).
- **Sert à** : exemples de situations.
- **Rang de départ** : 1 (2 si instinctive).
- **Usages prévus** : événements, combat, métiers, social…
- **Notes** : …
```

---

## Compétences implémentées

## Combat

## Armes de mêlée (`weapon_melee`)
## Armes de trait (`weapon_ranged`)
## Armes à poudre (`weapon_firearms`)
## Machines de guerre (`weapon_siege`)
- Ces compétences permettent d'utiliser certaines armes en combat
- **Implémenté** : bonus d'attaque = attribut de l'arme + rang de sa compétence. Toutes commencent au rang 1. Les
  armes à distance utilisent Armes de trait, les autres Armes de mêlée ; les mains nues prennent le meilleur rang
  entre Armes de mêlée et Physique. Aucune arme à poudre ni machine de guerre n'existe encore.

### Physique (`physique`) (instinctive)
- Décrit : si votre personnage est plutôt sportif ou non.
- sert à : se bagarrer à main nue, lancer des objets, grimper, nager, sauter, forcer une porte..., faire des acrobaties, garder l'équilibre, esquiver, tenir longtemps en apnée... faire de l'équitation...
- Attribut : Force si cela requiert de la force, Dextérité s'il s'agît de souplesse ou de coordination, Constitution s'il s'agît d'endurance. Il arrive qu'un jet prenne la meilleure valeur entre Force et Dextérité (un jet de Physique pour donner un coup de poing par exemple.).
- **En combat** : l'Empoignade (don Lutteur) ; les attaques à mains nues.
- Remplace Athlétisme et Acrobaties.

### Détermination (`determination`)
- Décrit : votre force de volonté : tenir bon face à la peur, à la douleur ou à la tentation, rester concentré,
  garder la foi.
- **Attribut** : SAG.
- **Sert à** : résister aux effets mentaux (peur, sommeil, charme…) ; compétence
  d'incantation des lanceurs de sorts divins (Clerc).
- Remplace l'ancienne compétence Magie (retirée pour le moment) dans le tableur des classes.

## Social

### Langues (`languages`)
- **Attribut** : CHA ou INT
- **Sert à** : vous faire comprendre d'un peuple avec qui vous ne partagez pas une langue connue, via des signes, sons basiques...
- Chaque rang permet de maîtriser une langue supplémentaire.
- Le commun est maîtrisé au niveau 0 et est la langue majoritairement utilisée.
- **Implémenté** : le Commun est connu de tous ; au rang 1, on choisit une langue (au hub), au rang 2 une deuxième…
  Langues provisoires : Commun, Elfique, Nain, Gobelin, Orque, Infernal (`rules.json › languages`). Elles
  dépendent des cultures et des régions, pas de l'espèce.
- **À venir** (avec les interactions sociales) : quand un PNJ parle une langue inconnue, son texte est « crypté », et
  certains caractères se déchiffrent selon le rang de Langues ; un jet de Langues permet de se faire comprendre
  (demander son chemin…) ; une langue maîtrisée permet une interaction sociale normale.

### Persuasion (`persuasion`) (instinctive)

- **Attribut** : CHA, Intimider se fait avec FOR
- **Sert à** : convaincre, négocier, séduire, marchander, tromper, mentir, manipuler
- **Notes** : servira aux prix des boutiques (achat et vente)
- **Implémenté** : prix des boutiques ; en combat, l'action **Intimider** (Persuasion avec la FOR contre la Sagesse
  de la cible : Effrayé). Remplace Tromperie et Intimidation.

### Perspicacité (`insight`) (instinctive)

- **Attribut** : SAG ou CHA
- **Sert à** : deviner les intentions, déceler un mensonge, détecter un sentiment caché, l'état mental de quelqu'un...


## Roublardise
### Escamotage (`sleight_of_hand`)
- Décrit : 
- Sert à : Voler à la tire, crocheter une porte, cacher un objet sur soit lors d'un contrôle, 
- Attribut : Dextérité en règle générale.

### Furtivité (`stealth`) (instinctive)
- Sert à : se cacher, se déplacer discrètement
- Attribut : Dextérité en règle générale.
- **En combat** : l'action **Se cacher** (Furtivité, difficulté 2 : caché, donc une attaque surprise ensuite, et
  Couvert +1 contre les tirs).

### Perception (`perception`) (instinctive)

- **Attribut** : INT ou SAG
- **Sert à** : chercher des indices, déduire, repérer un mécanisme, trouver des objets cachés, repérer, entendre, sentir (odorat ou instinct), suivre une piste
- **Implémenté** : la **Perception passive** (10 + bonus) est utilisable dans les conditions des événements
  (`{"type": "passive", "skill": "perception", "min": 13}`), pour repérer une embuscade sans lancer de dé.
  Remplace Investigation.


## Connaissances & Métiers

### Érudition (`lore`)

- Décrit : vos connaissances générales, votre "culture G". Pour les lanceurs de sorts arcaniques, c'est la compétence utilisée pour déterminer s'ils touchent avec leurs sorts.
- **Sert à :** reconnaître des créatures, sorts, objets, lieux, dieux...
- Attribut : Int
- Remplace Arcanes, Histoire et Religion (l'ancien id `nature` mène désormais à Nature).

### Artisanat (`crafting`)

- Décrit : votre aptitude à créer des objets, forger, bricoler...
- **Attribut** : Dextérité pour la réalisation d'un objet que vous connaissez, que vous avez pu observer (exemple reforger une épée), un jet réussi de Int est requis pour créer des plans au préalable et comprendre comment réaliser l'objet. Pour des objets complexes et composites (ex : construire une maison), plusieurs jets différents peuvent être requis pour réaliser chaque parties.
- **Sert à** : créer des objets « utiles » : armes, armures, outils, meubles…

### Arts (`arts`)

- **Attribut** : La valeur la plus élevée entre CHA et DEX. Avec CHA, l'oeuvre communiquera plutôt les émotions de son créateur, tandis qu'avec DEX il s'agîra plutôt d'une prouesse technique (une statue réaliste). Pour les lanceurs de sorts artistiques, c'est la compétence utilisée.
- **Sert à** : réaliser des objets ou des prestations « agréables » : peindre, chanter, sculpter, jouer…
- **Usages prévus** : métiers d'artiste, revenus en taverne, relations sociales.
- Remplace Représentation.


### Alchimie (`potions_cooking`)

- Décrit : votre capacité à reconnaître des ingrédients, à cuisiner, à préparer des recettes alchimiques (potions, remèdes, poisons, drogues)
- **Attribut** : SAG, INT ou DEX.
- **Sert à** : On peut utiliser cette compétence avec INT ou SAG pour trouver des ingrédients dans la nature (herbes...). Puis on peut réaliser des recettes ou plats connus avec des jets (DEX, INT ou SAG). Il est aussi possible d'inventer des plats / potions... en réalisant des jets d'INT ou SAG. On peut aussi utiliser cette compétence avec INT ou SAG pour détecter un poison ou un aliment spécifique dans un plat ou une boisson (avarié, ou un aliment auquel vous seriez allergique)...


### Médecine (`medicine`)

- Décrit : votre capacité à soigner des blessures ou maladies, arrêter les hémorragies, recoudre des plaies... soigner, diagnostiquer, stabiliser un mourant.
- **Attribut** : SAG, INT ou DEX.
- **En combat** : l'action **Premiers soins** (Médecine, difficulté 1 : soigne [rang de Médecine] d10 contre la
  SAG, un PV par succès, à un allié, une fois par combat).



### Nature (`survival`)

- Décrit : votre capacité à survivre dans un milieu sauvage, en vous procurant de la nourriture par la chasse/cueillette/pêche, en vous fabriquant un abri, en vous orientant... Vous pouvez aussi l'utiliser pour trouver des ingrédients en lieu et place d'Alchimie ou pister quelqu'un ou quelque chose. Pour les lanceurs de sorts Primaux, c'est la compétence utilisée.
- **Attribut** : SAG, INT et DEX


### Dressage (`animal_handling`)

- **Attribut** : SAG
- **Sert à** : calmer, monter ou dresser un animal.
- **Usages actuels** : aucun test d'événement pour l'instant.
- **Notes** : utile pour les voyages (montures) et les compagnons animaux.


---

## Compétences candidates (à compléter)


## Décisions (2026-10-13)

- **Progression** : pas par la pratique ; plutôt liée à l'XP et à la montée de niveau. Solution à trouver, puisque
  dans D&D une compétence est seulement maîtrisée ou non.
- **Rangs** : départ à 1 (2 si instinctive) ; pas de plafond après la création.
- **Classe et passé** : des rangs fixes (8 pour la classe, 4 pour le passé), plus 12 rangs libres.
- **Bonus de maîtrise** : remplacé par les rangs (compétences, attaques) ; résister est un simple test de compétence.
- **Dons et Expertise** : ils donnent des rangs.
- **Armes** : une compétence par famille d'armes ; mains nues et lancer : le meilleur entre l'arme et Physique.
- **Plusieurs compétences pour une même action** : c'est voulu (Nature ou Alchimie pour trouver des ingrédients…).

## Décisions (2026-10-15)

- **Progression des rangs** : les rangs de classe du tableur à la création (plafond de 5), puis un rang au choix
  tous les deux niveaux.
- **Jets de sauvegarde** : de simples tests de compétence, sans maîtrise de classe.
- **Vigilant** : supprimé. Les **soins** qui suivent le niveau (Second souffle) seront revus dans les classes ou
  les dons.
- **Magie** : retirée ; remplacée par la compétence d'incantation de chaque famille de magie. Nouvelle compétence
  Détermination. Potions et cuisine devient Alchimie, Survie devient Nature.


## Décisions (2026-10-16, reprises de questions_suite.md)

- « Magie » du tableur = Détermination : la foi du personnage, sa résistance à la peur et à certains effets
  mentaux ; c'est la compétence d'incantation des Clercs. « Potions » = Alchimie, « Survie » = Nature.

## Questions ouvertes

1. **Attaques et niveau** : sans bonus de maîtrise, une attaque ne progresse plus avec le niveau tant que les rangs ne
   le font pas. C'est à garder en tête pour la progression des rangs.
