# Questions pour la suite — Lifantasy

> Réponds directement sous chaque question (« => ... »), comme dans les autres fiches. Quand quelque chose est
> implémenté, on déplace la question/réponse dans la doc appropriée. Les réponses du 2026-10-18 sont rangées dans
> magie.md, equipements.md, bestiaire.md, lieux.md et systeme_de_jeu.md.

## En attente (tu t'en occupes)

1. **Sous-classes** : par quelle classe commencer, lesquelles écrire en premier, et que donne chaque palier
   (niveaux 6, 9, 12…) : une aptitude, un sort, une action de combat ? Quelle classe du tableur ajouter en premier
   (Rôdeur, Druide, Clerc, Barde, Pistolero…) ? => Tu t'en occupes ce week-end.

## Combat à deux armes et coup de bouclier

Ta réponse : « Pas convaincu, il va falloir que je retravaille le combat à deux armes. » Pour l'instant, le coup de
bouclier reste comme il est (variante de l'Attaque ; le bouclier ne pare plus jusqu'au prochain tour). Pistes :

1. **Piste A — la main secondaire coûte une action** : attaquer avec l'arme secondaire (ou le bouclier) est une
   action à part, sans malus de dés.
   - Pour : simple, lisible ; plus de « coup gratuit », donc plus besoin de contrepartie.
   - Contre : deux armes ne rapportent plus rien de plus qu'une seule arme ; le style À deux armes doit trouver
     autre chose (par exemple : la seconde attaque sans coût une fois par tour).
2. **Piste B — choisir à chaque tour : frapper ou parer** (ce qui est en place pour le bouclier, étendu à
   toute main secondaire) : frapper avec la seconde main la retire des parades jusqu'au prochain tour.
   - Pour : vrai choix tactique (offensive contre défensive), cohérent entre arme et bouclier.
   - Contre : demande d'expliquer clairement l'état « garde ouverte » au joueur ; l'IA doit savoir choisir.
3. **Piste C — une réserve de dés partagée** : avec deux armes, on répartit son rang de compétence entre les
   deux attaques (par exemple 4 dés : 3 + 1, 2 + 2…).
   - Pour : très « système à réserve de dés », la maîtrise compte ; pas de malus arbitraire.
   - Contre : une décision de plus à chaque attaque (interface plus lourde), moins bon avec peu de dés.
4. **Piste D — la seconde main donne un bonus plutôt qu'une attaque** : dague en main gauche = +1 dé de
   parade, bouclier = Armure +1 et parade des tirs ; le coup de bouclier devient une action à part (bousculer :
   la cible tombe à terre si elle rate une opposition de FOR).
   - Pour : chaque objet de main secondaire a un rôle distinct ; le coup de bouclier devient une manœuvre.
   - Contre : la fantaisie « deux lames qui frappent » disparaît, sauf avec le style À deux armes.
5. Ma recommandation : **B pour tous** (frapper ou parer avec la seconde main), et le style À deux armes qui
   permet de frapper avec la seconde main **et** de garder une parade. =>

## Nouvelles questions

1. **Petits objets lancés** : une fiole ou une pièce lancée compte comme une arme improvisée moyenne (5 dés).
   Faut-il une catégorie « petit objet » (3 ou 4 dés) ? =>
2. **Jet d'incantation** : la difficulté vaut le niveau du sort (Boule de feu : 3 succès). Un magicien de niveau 5
   a peu de dés : Boule de feu ratera souvent. Faut-il plutôt une difficulté de 1 pour tous, ou ½ niveau ? =>
3. **Munitions spéciales** : flèche de feu (+2 dés de feu, brûlure), de glace (+2 dés de froid, affaibli), de
   foudre (+3 dés de foudre), en vente à l'armurerie. Faut-il aussi pouvoir les fabriquer (forge, alchimie) ? =>
4. **Équipement des brigands** : chaque pièce a une chance sur deux de tomber en butin. Plus, moins ? =>
