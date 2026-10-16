# Système de magie — Lifantasy

> Document de conception : c'est ici qu'on décide comment la magie fonctionne (qui lance des sorts, comment on les
> apprend, ce qu'ils coûtent) et qu'on tient le catalogue des sorts, avant de les saisir dans
> `claude_rpg/data/actions.json`. Les champs techniques sont dans [modele_donnees.md](modele_donnees.md).
> Les idées marquées « à trancher » attendent une décision ; les autres sont des propositions qu'on peut garder.

## Ce qui existe

- **Familles de magie**, chacune avec sa compétence d'incantation : arcanique → Érudition (INT), divine →
  Détermination (SAG), primale → Nature (SAG), artistique → Arts (CHA seulement pour le moment).
- **Emplacements de sort** : la table du SRD par niveau de classe, convertie en une seule réserve (un sort de niveau
  N coûte N emplacements) ; lanceurs complets et demi-lanceurs. Ils reviennent au repos.
- **Sorts connus et sorts équipés** : parmi les sorts connus, on en équipe 2 + 1 par rang de la compétence
  d'incantation ; seuls les sorts équipés servent en combat.
- **Sorts de niveau 0** (sans emplacement) : Sont automatiquement équipés.
- **Sorts** : Projectile magique, Mains brûlantes, Sommeil, Bouclier, Appel du familier (niveau 1), Rayons ardents
  (niveau 2), Boule de feu (niveau 3).
- **Parchemins** : vendus à l'herboristerie ; lus & utilisés avec Langues, sans emplacement ; ils peuvent débloquer une classe.
- **Contresort** : une réaction gardée qui permet de tenter un jet de Compétence < seuil d'incantation, s'il y a plus de succès que le jet de sort adverse, son sort est annulé.
- **Plus de sorts appris par niveau** depuis la refonte des classes : il n'existe pour l'instant aucun moyen
  d'apprendre un nouveau sort.

## Questions à trancher

### 1. Qui peut lancer des sorts ?

- **A. Les classes de lanceurs seulement** (comme D&D) : sans classe de lanceur, aucun sort, même avec la compétence. Sauf utilisation de parchemins. => On garde le A, sauf exceptions éventuelles plus tard.
- **B. Tout le monde, selon la compétence** : la classe donne des sorts de départ et des facilités, mais n'importe
  qui peut apprendre un sort s'il a les rangs (un guerrier qui étudie devient un peu mage).
- **C. Mixte** : tout le monde peut apprendre des tours de magie et des rituels ; les vrais sorts demandent une
  classe ou un don (« Initié à la magie »).

### 2. Comment apprend-on un sort ?

Plusieurs sources peuvent coexister ; lesquelles garder ?

- À la montée de niveau (un sort au choix, comme avant).
- Auprès d'un maître (PNJ formateur, contre de l'or ou une faveur ; lié aux relations). => Non pour l'instant
- En étudiant un parchemin ou un grimoire (test d'incantation ; le parchemin est consommé ou non). => Uniquement pour les Magiciens.
- Par un événement (révélation, pacte, grotte ancienne, rêve). => Non pour l'instant.
- En expérimentant : créer un sort par l'Artisanat ou l'Érudition (mini-jeu de recherche, très long). => Non pour l'instant.
- Par la foi ou la nature : un clerc ou un druide reçoit ses sorts de son dieu ou de son cercle, selon sa
  réputation auprès d'eux (sorts « prêtés », qui peuvent être retirés). => Non pour l'instant.

### 3. Que coûte un sort ?

- **A. Emplacements** (actuel) : une réserve qui revient au repos. => Oui et on peut simplement appeler ça du Mana.
- **B. Mana / fatigue** : une jauge unique ; chaque sort coûte des points selon son niveau ; peut puiser dans les PV
  au-delà (dangereux). => J'aime bien l'idée de puiser dans les PV si on n'a pas assez de mana.
- **C. Sans réserve, mais avec un risque** : on peut toujours lancer, mais un échec critique déclenche un contrecoup
  (dégâts, état, effet sauvage) ; les gros sorts sont plus difficiles. => Il y aura effectivement des contrecoups en cas d'échecs critiques.
- **D. Composantes matérielles** : certains sorts consomment un objet (récolte, alchimie), ce qui lie la magie à
  l'économie. => Pas prévu pour l'instant.

### 4. Quelle puissance, quel jet ?

- Le lanceur fait un jet de sa compétence d'incantation (seuil : l'attribut de la famille) ; le sort réussit si les
  succès atteignent sa difficulté, qui monte avec son niveau.
  - La difficulté dépend du sort et de l'adversaire. Souvent il s'agît de toucher son Couvert (cas d'un sort d'attaque à distance), parfois son esquive naturelle (cas d'un sort d'attaque en mêlée), et plus rarement il s'agît d'un jet d'opposition entre la compétence d'incanttion du lanceur, et une compétence de résistance aux effets du défenseur (Physique ou Détermination par exemple), dans ce cas le sort réussit si le lanceur a plus de succès que le défenseur.
- Ses effets (dégâts, durée, cibles) montent-ils avec les succès en trop, comme les dégâts des armes ? Oui en cas de "critique N".
- L'équilibrage chiffré est remis à plus tard (comme pour les armes et les armures).

### 5. Combien de sorts, organisés comment ?

- **Niveaux de sort** de 1 à 9 comme D&D, ou quelques **cercles** (mineur, majeur, légendaire) ? => Des niveaux de sorts, de 0 à je ne sais pas trop combien, on va dire 10 pour la forme.
- **Écoles** (évocation, enchantement, nécromancie…) en plus des familles : utiles pour des dons (« Évocation
  renforcée »), des spécialisations de sous-classe, des factions qui interdisent une école ? => il y aura des sous classes, factions etc plus tard oui.
- **Sorts partagés entre familles** (Soins chez le clerc et le druide) ou listes séparées ? => Des listes de sorts spécifiques en fonction des sous classes, des domaines divins, des classes...

### 6. La magie hors combat

- Sorts utilisables dans les événements (choix débloqués par un sort connu : Lumière, Charme, Communication avec les
  animaux) ? => Oui potentiellement.
- **Rituels** : des sorts longs, sans emplacement, hors combat (détecter la magie, identifier un objet, invoquer un
  familier) ? => Oui potentiellement, ça reviendrait à écrire le sort sous la forme d'un parchemin / cercle magique en gros, et à lancer le parchemin.
- Magie dans les métiers : enchanter des objets (Artificier), potions (alchimie), soins payants. => Oui certaines classes/métiers pourraient enchanter/soigner/...

### 7. Place de la magie dans le monde

- Est-elle rare et crainte, ou banale ? Les PNJ réagissent-ils (réputation, traits « méfiant envers la magie ») ? Plutôt aussi fréquente que dans Warhammer Fantasy ou Faerun je dirais.
- Y a-t-il de la magie interdite (nécromancie), avec des conséquences légales ? => Oui il y a des conventions sociales en fonction des pays / peuples...
- Les sorts peuvent-ils traverser les vies (grimoire hérité, relique) ? Non pas pour l'instant.

## Pistes (non obligatoires)

- **Grimoire** : un objet qui contient les sorts connus du magicien ; le perdre, c'est perdre l'accès à ses sorts
  jusqu'à le retrouver ou le recopier. => Mouais pas convaincu de la pluvalue 
- **Sorts signature** : un sort qu'on a beaucoup lancé devient plus fort (ou moins cher). => Mmmmh éventuellement peut être un jour mais pas prévu atm
- **Magie sauvage** : une famille ou une sous-classe dont les échecs critiques déclenchent un effet aléatoire. => tous les sorts auront des effets néfastes en cas d'échec critique
- **Concentration** : un seul sort durable à la fois ; des dégâts peuvent le rompre (test de Détermination). => Mmmh pas certain, j'y réfléchis

## Modèle de fiche de sort (à copier)

```markdown
### <Nom> (`<id>`)

- **Famille** : arcanique / divine / primale / artistique (ou plusieurs).
- **Niveau** : tour de magie, 1, 2…
- **Coût** : …
- **Portée et cible** : un ennemi, tous les ennemis, soi, un allié…
- **Effet** : dégâts (type), soin, état, invocation…
- **Hors combat** : utilisable dans les événements ? Lesquels ?
- **Appris par** : niveau, maître, parchemin, événement…
- **Description** : une phrase d'ambiance.
```

## Catalogue des sorts

À compléter à partir des sorts existants (voir « Ce qui existe ») et des nouveaux.

## Décisions (2026-10-16, reprises de questions_suite.md)

- Mana = niveau de lanceur × 2 (Magicien 1 : 2 mana ; niveau 2 : 4, soit quatre sorts de niveau 1, deux de
  niveau 2, ou un de niveau 2 et deux de niveau 1) (fait).
- Un sort de niveau N coûte N mana ; les tours de magie sont gratuits.
- Faute de mana, on puise dans ses PV, 1 PV par mana manquant, jusqu'à 0 PV (donc la mort) ; l'IA ne le fait pas (fait).
- Le mana revient entièrement au repos long, et pour moitié du mana manquant au repos court (fait).
- Contrecoups d'échec critique : une table commune pour commencer, des tables propres plus tard (à faire).
- Concentration : un seul sort durable à la fois (à faire).
- Tours de magie : seuls ceux que l'on connaît sont automatiquement équipés.
- Multiclassage : le mana suit le niveau de lanceur total (Magicien 2 / Clerc 1 = 3 niveaux, 6 mana) (fait).
- Concentration : laissée de côté pour l'instant.

## Décisions (2026-10-16, deuxième série)

- **Dégâts des sorts** : un nombre de dés propre à chaque sort, comme les armes, seuil = attribut d'incantation
  (fait). Tours de magie : Trait de feu, Flammes, Glas 6 dés ; Rayon de givre, Fouet épineux, Flamme sacrée 5 dés
  (+1 dé aux niveaux 5, 11 et 17). Projectile magique 7 dés seuil 6, touche toujours. Mains brûlantes 8 dés.
  Rayons ardents 3 × 6 dés. Boule de feu 12 dés. Un sort lancé à un niveau supérieur : +2 dés par niveau.
- **Contrecoups** (fait) : quand le jet d'un sort (attaque, ou opposition contre la résistance de la cible) est un
  échec critique, on tire 1d10 sur la table commune, une fois par dé à 10 (au plus 3). N = niveau du sort (1 pour
  un tour de magie). Les dés « N d10 ≤ 4 ». Effets en général néfastes, pour un futur archétype « chaos » (beaucoup
  de dés, seuil faible).
  1. Le temps change (pluie, brouillard, beau temps…) pour le reste du combat.
  2. Un combattant au hasard est soigné de N d10 ≤ 4.
  3. Un combattant au hasard subit N d10 ≤ 4 dégâts d'un type au hasard.
  4. Tout le monde subit N d10 ≤ 4 dégâts d'un type au hasard.
  5. Tout le monde récupère N d10 ≤ 4 PV.
  6. (proposition) Le sort explose : le lanceur subit N + 1 d10 ≤ 4 dégâts de force.
  7. (proposition) Le lanceur perd N mana.
  8. (proposition) Le lanceur reçoit un état au hasard (empoisonné, en feu, affaibli, aveuglé, effrayé, à terre), 2 charges.
  9. (proposition) Tous les combattants deviennent préparés (+2 dés au prochain jet).
  10. (proposition) Le lanceur est étourdi (perd son prochain tour).
- Les sorts sans jet du lanceur (Projectile magique, Mains brûlantes, Boule de feu, Bouclier, Appel du familier)
  ne peuvent pas faire d'échec critique pour l'instant.
