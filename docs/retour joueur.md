Retour de joueur le 15/10 sur une version du 14/10 en ligne sur github pages :

- Implémenter une fonctionnalité pour "chercher la bagarre" car il a dû tourner en boucle pour trouver les loups.
  => Je privilégierais une solution où on pourrait faire un jet pour réfléchir à où trouver la créature / l'objet de la quête en cliquant dessus dans le journal par exemple.
  => Si on est dans la région / zone où on peut trouver ce que l'on cherche, le bouton "chercher..." qui permet de chercher un NPC devrait pouvoir permettre de trouver la créature.
  => Le bouton "chercher" devrait globalement permettre de :
  - Parler à quelqu'un que l'on connaît qui est dans la zone
  - Chercher un NPC à qui parler au hasard parmi ceux présents que l'on ne connaît pas => en ville pas de jet, dans la nature le jet aurait une difficulté élevée, et en cas d'échec un combat se lance avec une créature
  - Chercher une créature spécifique dont on sait qu'elle est ici => Jet de nature dans la nature, en cas d'échec on ne trouve pas la bonne, mais un combat se lance quand même (en ville on pourrait ainsi chercher des brigands par exemple ?)
  - Chercher des ressources (plantes, matériaux, nourritures) => Jet de Nature dans la nature notamment ; en cas d'échec un combat pourrait se lancer
  => La difficulté du combat dépendrait notamment du nombre d'échec critique. Sauf si on cherchait spécifiquement cette créature, auquel cas il y en a davantage en fonction du nombre de succès critique !

- Ralentir les combats
  - => Pas eu l'impression de pouvoir comprendre ce qu'il se passait par moment, les dés vont vite, ils ne devraient disparaître de l'écran que si on clique par exemple, et l'on ne devrait passer au jet d'attaque adverse que si l'on clique admettons (ça rend le jeu un peu clicker-like, mais c'est pas forcément un mal, à tester).