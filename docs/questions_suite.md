# Questions pour la suite — Lifantasy

> Réponds directement sous chaque question (« => ... »), comme dans les autres fiches. Quand quelque chose est
> implémenté, on déplace la question/réponse dans la doc appropriée. Les réponses du 2026-10-18 sont rangées dans
> magie.md, equipements.md, dons.md, bestiaire.md, lieux.md, systeme_de_jeu.md et modele_donnees.md.

## En attente (tu t'en occupes)

1. **Sous-classes** : par quelle classe commencer, lesquelles écrire en premier, et que donne chaque palier
   (niveaux 6, 9, 12…) : une aptitude, un sort, une action de combat ? Quelle classe du tableur ajouter en premier
   (Rôdeur, Druide, Clerc, Barde, Pistolero…) ? => Tu t'en occupes ce week-end.

## Nouvelles questions

1. **Équipement des brigands** : chaque pièce a une chance sur deux de tomber en butin. Plus, moins ? => Difficile à dire pour l'instant.

## Bilan et cap (2026-10-19)

> Où on en est : 3 classes (Guerrier, Roublard, Magicien) avec une sous-classe chacune, 6 espèces, 2 lieux
> (Brumeval et la forêt) plus le domicile, ~150 événements, combat aux d10 complet (réactions, deux mains, sorts à
> dés, contrecoups, fuyards), social et romance, économie et fabrication, Chercher…, combat au clic, sauvegardes et
> Creator Points. La version en ligne (GitHub Pages) date du 14/10. Les questions ci-dessous servent à décider de la
> suite ; les questions de détail restent dans chaque fiche (je les cite quand elles bloquent).

### A. Priorités

2. **Prochain grand chantier** : lequel passe en premier ? Pistes : nouvelles classes (attend les sous-classes),
   deuxième région et voyages ([temps_et_voyages.md](temps_et_voyages.md)), temps long (activités de plusieurs
   années), contenu (événements, quêtes, créatures), interface et lisibilité, équilibrage. => Pas l'équilibrage, il reste trop de systèmes inter connectés à peaufiner d'abord. On peut essayer vaguement de design les Classes & Sous-Classes pourquoi pas, ou du moins certaines.
3. **Nouvelle version de test** : faut-il mettre à jour la version en ligne (merge `dev` → `main`) maintenant, pour
   avoir des retours sur Chercher…, le combat au clic et la magie ? => Oui.
4. **Testeurs** : combien sont-ils, et préfères-tu des sessions guidées (« essaie le Magicien jusqu'au niveau 3 ») ou
   libres ? Faut-il un petit formulaire de retour dans le jeu (touche, lien) ? => Non.
5. **Une vie complète** : combien de temps de jeu réel vises-tu (1 h, 5 h, plus) ? Cela décide du rythme d'XP, du
   temps long et de la quantité de contenu à produire ([progression.md](progression.md) §3,
   [temps_et_voyages.md](temps_et_voyages.md)). => Plutôt une session de 20-30 min pour une vie au début, avec les risques de mort que l'on ne connaîtrait pas, mais ça pourrait durer bien plus longtemps en soit

### B. Ce qu'on ajoute ou non

Pour chaque idée : **oui** (on le fera), **plus tard**, ou **non** (on l'abandonne).

1. **Carte du monde** pour choisir sa destination ([lieux.md](lieux.md) q. 2) => Ca peut être sympa effectivement, plutôt que de lister chaque endroit accessible depuis la ville 1 par exemple, on pourrait avoir à chaque endroit un bouton pour ouvrir la Map, ce qui indiquerait des Points (les lieux) rouges (lieux sauvages), bleus ("safe place" comme des villes) et verts (là où on est actuellement) avec des segments. Chaque cercle serait entouré de doré s'il est cliquable (càd si on l'a déjà visité et qu'on peut s'y téléporter). La téléportation est surtout par simplicité pour l'instant. **Fait (2026-10-19)** : touche V ou « Carte » dans le menu du lieu ; un voisin pas encore visité est aussi accessible (contour clair).
2. **Métiers sédentaires** jouables (s'établir forgeron, marchand, aubergiste…) au-delà de la forge => Dans l'idée ce serait juste comme d&d, rien empêche un joueur qui a fait un personnage avec une classe et une espèce de décider de s'installer dans un village et d'y accomplir un rôle d'artisan.
3. **Jouer son enfant ou son conjoint** à la mort du héros (lignée) => Pour l'instant non.
4. **Revenir à la vie** (temple, rituel, compagnons) ([lieux.md](lieux.md) q. 3) => Pour l'instant uniquement à la fin d'un combat s'il reste un compagnon en vie, et de façon automatisée. **Déjà en place** : les membres tombés reprennent connaissance à 1 PV après une victoire ou une fuite.
5.  **Factions** avec réputation, adhésion et grades ([factions.md](factions.md)) => Oui, il faudra que je détaille le lore plus tard.
6.  **Météo et saisons** ([environnement.md](environnement.md) q. 2) => Oui.
7.  **Terrain et surfaces en combat** (hauteur, embuscade, flaques élémentaires) ([environnement.md](environnement.md)) => Oui au moins pour les flaques ou embuscades
8.  **Besoins en route** (vivres, eau, fatigue) ou voyages abstraits ([temps_et_voyages.md](temps_et_voyages.md)) => Oui, qui sont remplis par la compétence Survie en général.
9.  **États hors combat** (maladies, malédictions, fatigue durable) ([etats.md](etats.md)) => Oui.
10. **Contresort** et réactions magiques => Oui, on pourrait aussi imaginer un sort de bouclier magique, pour effectuer une parade avec la caractéristique d'incantation. **Fait** : le contresort existait ; le sort Bouclier sert maintenant aussi à parer (Magie contre le seuil d'incantation, coût en mana).
11. **Son et musique** : quand, et d'où viendraient-ils (banques libres, IA, composition) ? => Aucune idée.
12. **Traduction anglaise** : à quel moment ? => Aucune idée.
13. **Export Windows** (itch.io, Steam un jour ?) ou seulement le Web pour l'instant ? => Pour l'instant uniquement Web.
14. **Tactile / mobile** : à viser, ou seulement la souris ? =>Si possible il faut permettre la compatibilité mobile oui.

### C. Systèmes où il me manque des informations

20. **Progression** ([progression.md](progression.md)) : les questions 1 (sources d'XP), 2 (une ou plusieurs XP),
    3 (rythme et table) et 6 (perdre de la progression) sont sans réponse. Elles bloquent l'équilibrage sur une vie.
    Peux-tu y répondre, même rapidement ? =>répondu dans le dit document. Mais dans tous les cas on est pas vraiment en train de gérer l'équilibrage à ce stade.
21. **Temps long** ([temps_et_voyages.md](temps_et_voyages.md)) : activités de plusieurs années, ce qu'elles donnent,
    si le joueur intervient pendant le résumé, si on peut être interrompu. Tout est encore ouvert. => 
22. **Deuxième lieu** : quel lieu ajouter après la forêt (mine, route, rivière, ruines, temple, village voisin…) et
    combien de lieux pour la première région ([lieux.md](lieux.md) q. 1, [evenements.md](evenements.md)) ? => Peu importe pour l'instant, on est vraimetn qu'aux phases de tests avec des lieux "basiques" qui ne resteront probablement pas à terme. Le but est avant tout de tester la robustesse des systèmes, leur modularité...
23. **Lore** ([monde.md](monde.md)) : nom du monde et de la région, raison des renaissances, menace qui progresse
    d'une vie à l'autre, place de la magie. Peux-tu m'envoyer un premier morceau, même en vrac ? => On va voir ça ensmble plus tard.
24. **Dons de classe à définir** ([classes.md](classes.md)) : Parangon, Paysan, Pistolier, Artificier, Moine. Les
    écris-tu avec les sous-classes, ou veux-tu que je propose une première version ? => Je vais écrire des ébauches avec des idées / thèmes qui doivent revenir, rôles que doivent remplir ces classes etc.
25. **Descendance des espèces** ([especes.md](especes.md)) : que donne un enfant de parents d'espèces différentes
    (espèce d'un parent au hasard, espèce mixte, traits mélangés) ? Les enfants existent déjà, la règle manque. => Pour l'instant, une espèce d'un parent au hasard c'est suffisant. **Déjà en place**.
26. **États** ([etats.md](etats.md)) : combien d'états au total, résistance aux états (moitié des charges), une icône
    par état ? => A voir plus tard quand j'aurais peaufiné d'autres systèmes.
27. **Boss et fins de quête** : l'Alpha est le seul boss. Faut-il un boss par lieu, des boss rares qui reviennent
    d'une vie à l'autre, une grande menace finale ? => Ca peut varier d'une vie à l'autre. Certaines régions dans une vie peuvent n'avoir qu'un boss, alors que dans une autre la forêt aura été envahie par un nécromancien.
28. **Monnaie méta et déblocages** : les Creator Points sont provisoires. Quelles espèces et classes doivent être
    verrouillées au départ, et par quel haut-fait se débloquent-elles ? => Peu importe pour l'instant, tout doit être débloqué en mode débug. **Fait**.
29. **Monde persistant** : quels flags doivent survivre à la mort (PNJ tués, lieux détruits, tombe du héros, objets
    cachés à retrouver) ? Jusqu'où va la mémoire du monde ? => Je ne sais pas.
30. **Compagnons** : faut-il des compagnons écrits à la main (histoire, quête personnelle, dialogues), en plus des
    PNJ générés ? Combien, et pour quand ? => Pour l'instant non.
31. **Fins de vie** : en dehors de la mort et de la vieillesse, peut-on prendre sa retraite volontairement (finir
    sa vie en paix et passer au suivant) ? => Oui pourquoi pas, mais ça reviendrait probablement à passer du temps (via le système des temps longs) et "tuer" le personnage de vieillesse.

### D. Interface et confort

32. **Choix nombreux** : en combat, garder la liste actuelle ou passer à des menus (Attaque / Sorts / Objets) ou une
    barre d'icônes ([evenements.md](evenements.md)) ? => Probablement utile d'avoir des menus. Je préfère éviter les clics nombreux si possible cela dit (pour ouvrir un menu dans un menu). Sur PC ça peut être évité via des systèmes de Hover, mais je vois pas tellement de solution sur mobile. **Fait** : catégories Attaques, Sorts, Capacités, Objets, Lancer, ouvertes au survol ou au clic.
33. **Tutoriel** : faut-il une première vie guidée, des bulles d'aide, ou un écran « Comment jouer » ? => Oui la première vie lancée aurait un didacticiel, qui peut être réinitialisé ou non à la création de personnage. **Reporté** : quand les systèmes seront stabilisés.
34. **Ce qui te gêne** quand tu joues toi-même en ce moment (lenteur, lisibilité, clics de trop, textes) ? => Plutôt les choix visuel des boutons en combat actuellement je dirais.
