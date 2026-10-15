# Questions pour la suite — Lifantasy

> Réponds directement sous chaque question (« => ... »), comme dans les autres fiches. Les questions suivent tes
> réponses dans magie.md, progression.md, bestiaire.md et evenements.md, et le nouveau tableur Classes.ods.

## Passés et dons

1. Le tableur nomme deux lignes autrement que le jeu : « Magie » (en face de Détermination), « Potions » (Alchimie),
   « Survie » (Nature). Faut-il renommer ces compétences dans le jeu, ou seule l'étiquette du tableur diffère ?
   => Effectivement on remplace la compétence "Magie" par "Détermination", celle ci sert à représenter la foi d'un personnage, sa résistance à la peur et certains effets mentaux (et est donc la manière de lancer des sorts pour les Clercs par exemple.)
2. Courtier n'a que 4 dons au choix : quel 5e ? mets en un approprié
3. « Tactical Mind » (Gladiateur) = Tacticien, ou un don différent ? Tacticien oui.
4. Les anciens passés absents du tableur (Charlatan, Saltimbanque, Héros du peuple…) : supprimer ou garder ? Saltimbanque est devenu Artiste. Charlatan & Héros du peuple tu peux les adapter au système du tableur si tu le souhaites.
5. Le passé « Sur mesure » sera bloqué plus tard : par quel succès le débloquer ? Je ne sais pas encore, ce n'est pas prioritaire.
6. Les dons « 1/jour » : le dé de plus est-il choisi avant le jet (on décide de le dépenser) ou après avoir vu le résultat ? Après avoir vu le résultat.
7. Les dons d'origine déjà en jeu (version D&D : Initié à la magie avec 2 tours + 1 sort, Doué à 3 compétences…) sont-ils
   remplacés par tes versions du tableur ? (Je suppose que oui.) => oui, de manière générale on s'éloigne de D&D donc tu peux commencer à enlever les dons d&d.
8. Les pistes de passés ajoutées dans passes.md (Chasseur, Mercenaire, Espion…) : lesquelles garder ? => On les laisse en simples pistes
9. Faut-il un or ou un objet de départ propre à chaque passé (le Noble avait 25 po) ? => A priori non pour l'instant.

## Magie (suite de magie.md)

1. Mana : combien au niveau 1, et d'où vient-il (attribut d'incantation, niveau, classe) ? On peut dire environ avoir Niveau de lanceur de sort x 2 mana au total ? pour l'instant.
2. Puiser dans les PV faute de mana : combien de PV par point de mana manquant ? 1 pour 1.
3. Contrecoups d'échec critique : une table commune (dégâts, état, perte de mana) ou propre à chaque sort ? Une table commune au début, plus tard peut être que j'en ferais des différentes.
4. Concentration : à trancher (un seul sort durable à la fois, oui/non). pour l'instant go dire oui.
5. Les tours de magie (niveau 0) « automatiquement équipés » : tous ceux de la classe, ou un nombre limité ? seuls ceux connus/appris sont automatiquement équipés.

## Progression (suite de progression.md)

1. Dons tous les 4 niveaux (4, 8, 12, 16, 20) : en plus de l'attribut des niveaux 5/10/15/20 du tableur, ou à la place ? En plus, ce sont deux choses différentes (on aurait tous les 3 niveaux qqch en lien avec la subclass, tous les 2 niveaux un rang de compétence, tous les 5 niveaux un attribut, et tous les 4 niveaux un don)
2. Le niveau 20 « très difficile » : par une XP qui grimpe fort, ou par une condition (un exploit) ? XP qui grimpe fort à priori.
3. Titres / succès : une liste de 10 premiers titres que tu aimerais voir ? => Pas prioritaire du tout.

## Bestiaire (suite de bestiaire.md)

1. Créatures célestes et démoniaques : une catégorie, deux, ou aucune ? => Aucune pour l'instant.
2. Budget de rencontre par difficulté de zone : quelle échelle (ex. zone 1 à 5) ? => à tester
3. « Chercher les points faibles » en combat : une action qui coûte le tour, ou une action bonus ? coûte une action, deux si on veut la lancer avec +2 dés (état préparé puis faire l'action)
4. Les ennemis qui fuient et reviennent : pour quelles catégories (humanoïdes seulement, ou bêtes intelligentes aussi) ? des bêtes sauvages pourraient aussi fuir

## Événements (suite de evenements.md)

1. Lieu de départ selon le passé (Marin au port, Ermite en forêt) : on le fait dès maintenant ? => Pourquoi pas.
2. Narration : deuxième personne (« Vous trouvez… ») pour tout, ou le narrateur + répliques des personnages à la BG3 ? => Narrateur uniquement pour l'instant, sauf quand les personnages (PC ou NPC) parlent à la première personne.
3. Options d'affichage (compétence, difficulté, probabilité, choix verrouillés) : un seul interrupteur ou plusieurs ? plusieurs paramètres dans un menu option.

## Priorité de la prochaine session

Implémenter ce qui a changé dans la doc récente et qui n'est pas encore sur la branche Dev en code.
---

## Fait (2026-10-15)

- Passés du tableur en jeu : 17 passés + Charlatan et Héros du peuple adaptés + Sur mesure ; don choisi parmi 5 à la
  création ; Courtier : 5e don = Linguiste ; plus d'or de passé.
- Dons d'origine D&D remplacés par ceux du tableur (détail dans dons.md). Les dons 1/jour s'utilisent d'office après
  un test raté. Frappe brutale = un dé de dégâts de plus, une fois par tour.
- Initié à la magie en trois versions (clerc, magicien, druide), avec 4 nouveaux tours de magie.

## Prochains chantiers (d'après tes réponses)

- Mana = niveau de lanceur × 2, PV à la place du mana manquant (1 pour 1), concentration, table commune des contrecoups.
- Progression : un rang de compétence tous les 2 niveaux, sous-classe tous les 3, attribut tous les 5, don tous les 4 ;
  bouton « Monter de niveau » qui brille sur la fiche.
- Action « Chercher les points faibles » (1 action, ou 2 avec +2 dés).
- Lieu de départ selon le passé ; menu d'options d'affichage des tests.

## Nouvelles questions

### Dons

1. Les dons 1/jour : les garder automatiques (le dé s'ajoute dès qu'un test rate), ou une fenêtre « Utiliser Costaud ? »
   à chaque échec (plus de contrôle, plus de clics) ? => Pour les dons une fois par jour, fais en sorte qu'une option dans le menu permette de désactiver le choix automatique (peut être qu'on veut garder le dé supp pour un jet plus important)
Chanceux de même doit transformer un échec critique "2" en échec critique "1".
2. Les dons généraux encore D&D (Lutteur, Duelliste défensif, Résistant, Adepte élémentaire, Entraînement aux armures
   lourdes) et les styles de combat : on les garde pour les dons de niveau 4, 8…, ou tu en écris une liste à toi
   (dans le tableur, feuille Dons) ? => j'en écrirais à terme une liste à moi, notes donc bien lesquels viennent de d&d pour savoir lesquels supprimer / modifier / changer à l'avenir.
3. Un don de niveau peut-il être un don d'origine (prendre Chanceux au niveau 4) ? => Non.

### Mana

1. Un sort de niveau N coûte-t-il N mana (tours de magie gratuits) ? => Oui.
2. « Niveau de lanceur × 2 » : un Magicien 1 a donc 2 mana, soit deux sorts de niveau 1 par jour. Assez ? Faut-il un
   bonus selon l'attribut d'incantation ? => ça me va très bien 2 sorts au niveau 1, puis 4 au niveau 2 (soit 4 de niveau 1 ou deux de niveau 2 ou un de niveau 2 et deux de niveau 1)
3. Le mana revient-il entièrement au repos long, et en partie au repos court ? => entièrement au repos long oui. Un repos long doit correspondre à 2 périodes de temps passées, un repos court à une seule période (un repos long peut être interrompu par un évènemetn dans la nature : une embuscade...), et on va décomposer la journée en périodes de 4h :
0-4 = nuit
4-8 = aube
8-12 = matin
12-16 = après midi
16-20 = soirée
20-4 = couché
1. Puiser dans les PV : possible jusqu'à tomber à 0 PV (donc mourir), oui jusque 0 pv admettons.

### Progression

1. Rang de compétence tous les 2 niveaux : niveaux pairs (2, 4, 6…) ? Le tableur l'indique aux niveaux 2 et 4. => fais bien aux niveaux pairs.
2. Sous-classe tous les 3 niveaux : niveaux 3, 6, 9, 12, 15, 18 ? (Le tableur dit 3, 6, 9, 12, 16.) => Fais bien tous les 3 niveaux.
3. Table d'XP « qui grimpe fort » pour la fin : on garde celle de D&D jusqu'au niveau 10 et on la double au-delà ? => on garde celle de d&d pour l'instant par simplciité.

### Lieu de départ

1. Quels lieux de départ veux-tu ? Proposition : port (Marin, Pirate, Contrebandier), campagne (Fermier, Vagabond,
   Héros du peuple), temple (Acolyte), forêt (Ermite), ville (les autres). => Peu importe c'est pour tester plus qu'autre chose
2. Ces lieux sont-ils de vrais nouveaux lieux (avec PNJ et boutiques), ou des quartiers de la ville de départ ? => des quartiers de la ville pour l'instant.

## Fait (2026-10-15, suite)

- Création : listes longues (passés, dons et compétences du passé Sur mesure) sur une ligne qui défile.
- Mana = niveau de lanceur × 2 ; le manque se paie en PV ; l'IA ne le fait pas.
- Options : dons 1/jour manuels ou automatiques, affichage des tests (compétence, probabilité), choix verrouillés,
  rythme des combats au clic. Chanceux : un degré d'échec critique en moins (degré = dés à 9 ou 10).
- Progression : don tous les 4 niveaux (pas d'origine), sous-classe tous les 3 niveaux, bouton « Monter de niveau ».
- Six périodes de 4 h ; repos court (1 période) et long (2 périodes).
- Quartier de départ selon le passé ; action « Chercher les points faibles » ; menu « Chercher… » (retour joueur).

## Nouvelles questions (2026-10-15)

### Temps et repos

1. Repos court : la moitié des PV manquants, sans mana. Faut-il qu'il rende un peu de mana (1 point ?) ?
2. Combien de repos courts par jour, au plus ?
3. Une vie commence le matin : faut-il qu'elle commence à l'aube pour certains passés (Fermier, Marin) ?

### Chercher…

1. Difficulté des chasses : loups 2, camp des brigands 3, brigands en ville 2 (Perception). Ça te va ?
2. En ville, chercher des brigands : vrai combat dans les ruelles, ou une bagarre non mortelle (on est assommé) ?
3. Chercher un PNJ précis qu'on connaît mais qui n'est pas là (« Où est Ysolde ? ») : un test de Perspicacité qui
   indique où il est à cette période ?

### Points faibles

1. Les points faibles découverts restent-ils connus pour toutes les créatures de la même espèce (carnet de bestiaire) ?
2. Érudition pour tout, ou Nature pour les bêtes et Détermination pour les morts-vivants ?

### Combat au clic

1. Faut-il aussi attendre un clic entre les attaques d'un même ennemi (attaques multiples) ?
2. Une touche (Espace) pour avancer plus vite que la souris ?
