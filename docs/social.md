# Interactions sociales — Lifantasy

> Document de conception : il décrit le système social (PNJ, relations, dialogues, romance, monde autonome) et
> recense ce qui doit exister dans le jeu : rôles de PNJ (`npc_roles.json`), traits (`traits.json`), faits
> (`npc_facts.json`), actions de dialogue (`social_actions.json`), réglages (`rules.json › social`).

## Règles générales

- **Les PNJ appartiennent au monde** : ils survivent à la mort du héros, vieillissent avec l'horloge du monde (qui
  continue d'une vie à l'autre) et **se souviennent** des héros passés (« Vous me rappelez quelqu'un… »).
- **Génération progressive**, comme un MJ de JdR papier : un habitué (la forgeronne…) est créé à la première visite
  de son lieu ; on peut « chercher » un garde ou un villageois, créé à la demande. À la rencontre, un PNJ a un nom,
  une espèce, un âge, un rôle et **un trait visible**. Ses **faits** (origine, famille, rêve, peur, passe-temps,
  secret, opinion) n'existent qu'une fois appris, et deviennent alors définitifs. Un fait de famille peut faire
  apparaître un parent du PNJ.
- **Relation avec le héros** : trois jauges de −100 à +100, **Amitié**, **Amour**, **Confiance**, et un statut :
  inconnu, connaissance, ami (Amitié 30), proche (60), rival (−30), ennemi (−60), en couple, fiancé, marié, avec
  éventuellement une **relation libre**. Plusieurs relations à la fois sont possibles (relations polyamoureuses).
  Les relations ne s'usent pas avec le temps pour l'instant.
- **Réputation par lieu** (−100 à +100) : Inconnu, Apprécié, Respecté, Mal vu, Honni.
- **Personnalité** : 2 traits par PNJ (certains cachés), des goûts (une catégorie d'objets aimée, une détestée) et
  une **humeur du jour** (radieux, de bonne humeur, neutre, maussade, furieux) qui rend les tests plus faciles ou
  plus difficiles et les gains plus ou moins grands.
- **Perspicacité** : à la rencontre, la Perspicacité passive du héros (10 + bonus) contre 10 + la Persuasion du PNJ
  révèle son humeur ; 5 de plus révèle un trait caché. Les actions risquées opposent la Persuasion du héros à la
  Perspicacité du PNJ.
- **Pas de restriction** d'espèce ni de genre pour la romance (comme dans BG3) ; les traits jouent sur les réactions.
  Les actions romantiques sont réservées aux adultes (18 ans).
- **Une conversation** se fait dans une fenêtre à la façon des Sims (barre d'actions en bas) ; quand on la quitte
  après au moins une action, **un créneau de la journée passe**.
- **Échange** (à la façon de BG3) : acheter, vendre, **offrir** (cadeau : Amitié selon la valeur et les goûts, Amour
  pour un partenaire) ou **demander gratuitement** (Persuasion contre Perspicacité, plus dur pour un objet cher ;
  facile auprès d'un ami). Un PNJ marchand échange le stock de sa boutique ; un autre, ses affaires et son or. Un ami
  fait 5 % de remise, un proche 10 %.
- **Langues** : si le héros ne parle aucune langue du PNJ, ses paroles (entre « ») sont **cryptées** : chaque rang de
  Langues révèle une lettre (e, s, a, i, t…). Les tests ont alors le désavantage, sauf après « Communiquer par
  gestes » réussi.
- **Monde autonome** : chaque jour, des PNJ d'un même lieu se rencontrent : amitiés, rivalités, couples (annoncés par
  des **rumeurs**), naissances.
- **Jalousie** : une réussite romantique peut être apprise par un partenaire sans relation libre (chance de 50 %,
  plus forte chez un jaloux) : Amour et Confiance baissent.
- **Compagnons à la BG3** : un choix d'événement peut porter `"approval": {"mira": 2}` ; l'Amitié du compagnon
  change, et sous -50 il quitte le groupe. On peut **recruter** un PNJ ami (Amitié 60) dont le rôle a une classe.

---

## Rôles de PNJ

### Forgeronne (`blacksmith`)

- **Lieu** : Brumeval.
- **Présence** : habitué (créé à la première visite).
- **Personnage fixe** : Hilde, Nain.
- **Commerce** : sa boutique (`forge`).
- **Recrutable** : oui (classe : fighter).

### Armurier (`armorer`)

- **Lieu** : Brumeval.
- **Présence** : habitué (créé à la première visite).
- **Personnage fixe** : Gorvald, Humain.
- **Commerce** : sa boutique (`armorer`).
- **Recrutable** : oui (classe : fighter).

### Herboriste (`herbalist`)

- **Lieu** : Brumeval.
- **Présence** : habitué (créé à la première visite).
- **Personnage fixe** : Maëlle, Elfe.
- **Commerce** : sa boutique (`apothecary`).
- **Recrutable** : oui (classe : wizard).

### Aubergiste (`innkeeper`)

- **Lieu** : Brumeval.
- **Présence** : habitué (créé à la première visite).
- **Commerce** : ses affaires (potion_heal, healing_herbs), bourse 4d10 po.

### Garde (`guard`)

- **Lieu** : Brumeval.
- **Présence** : à chercher (créé à la demande).
- **Commerce** : ses affaires (dagger), bourse 2d6 po.
- **Recrutable** : oui (classe : fighter).

### Villageois (`villager`)

- **Lieu** : Brumeval.
- **Présence** : à chercher (créé à la demande).
- **Commerce** : ses affaires (healing_herbs, wolf_pelt), bourse 1d10 po.
- **Étranger** : 15 % de chances de ne parler qu'une autre langue.

### Bûcheron (`woodcutter`)

- **Lieu** : Forêt des Murmures.
- **Présence** : à chercher (créé à la demande).
- **Commerce** : ses affaires (handaxe, wolf_pelt), bourse 1d6 po.
- **Recrutable** : oui (classe : fighter).

---

## Traits de personnalité

### Jovial (`jovial`)

- **Description** : Toujours le mot pour rire.
- **Réactions** : Plaisanter (DD -2, gains ×2.0) ; Discuter (gains ×1.5).

### Colérique (`grumpy`)

- **Description** : S'emporte pour un rien.
- **Réactions** : Provoquer (gains ×2.0) ; Insulter (gains ×2.0) ; Plaisanter (DD +3).

### Timide (`shy`)

- **Description** : Rougit quand on lui parle.
- **Réactions** : Complimenter (gains ×2.0) ; Flirter (DD +2) ; Discuter (gains ×0.7).

### Cupide (`greedy`) — caché

- **Description** : Ne pense qu'à l'argent.
- **Réactions** : Offrir (gains ×1.5) ; Demander gratuitement (DD +5).
- **Aime recevoir** : treasure.

### Romantique (`romantic`)

- **Description** : Rêve d'un grand amour.
- **Réactions** : Flirter (DD -2, gains ×1.5) ; Complimenter (gains ×1.3).

### Pieux (`pious`)

- **Description** : Prie matin et soir.
- **Réactions** : Insulter (gains ×1.5) ; Plaisanter (gains ×0.7).

### Curieux (`curious`)

- **Description** : Pose mille questions.
- **Réactions** : Se renseigner (gains ×2.0) ; Discuter (gains ×1.3).

### Méfiant (`suspicious`) — caché

- **Description** : Ne fait confiance à personne.
- **Réactions** : Flirter (DD +3) ; Demander gratuitement (DD +3) ; gain de Confiance (gains ×0.5).

### Jaloux (`jealous`) — caché

- **Description** : Ne partage pas ceux qu'il aime.
- **Refuse** : Proposer une relation libre.
- **Jalousie** : ×2.0.

### Généreux (`generous`)

- **Description** : Donne sans compter.
- **Réactions** : Demander gratuitement (DD -4) ; Offrir (gains ×1.2).

### Fier (`proud`)

- **Description** : Supporte mal qu'on le contredise.
- **Réactions** : Complimenter (gains ×1.5) ; Provoquer (gains ×1.5) ; Intimider (DD +3).

### Esprit libre (`free_spirit`) — caché

- **Description** : Méfiant envers les attaches exclusives.
- **Réactions** : Proposer une relation libre (DD -6) ; Demander en fiançailles (DD +4).

---

## Faits révélables

### Origine (`origin`)

- Né{g:|e|·e} dans un hameau de montagne, {npc} est descendu{g:|e|·e} en ville pour trouver du travail.
- {npc} a grandi au bord de la mer et en garde la nostalgie.
- {npc} vient d'un pays lointain dont plus personne ne prononce le nom ici.
- {npc} n'a jamais quitté Brumeval, et s'en vante.

### Famille (`family`)

- **Crée un parent** du PNJ (frère, sœur…), lié par une relation de famille.
- {npc} a {relative_kind} : {relative}, qui vit aussi par ici.
- {npc} parle souvent de {relative_kind}, {relative}, avec qui les rapports sont compliqués.

### Rêve (`dream`)

- {npc} rêve d'ouvrir sa propre échoppe.
- {npc} voudrait voir la mer avant de mourir.
- {npc} espère qu'on écrira un jour une chanson sur {g:lui|elle|iel}.
- {npc} rêve d'une vie tranquille, loin des monstres et des guerres.

### Peur (`fear`)

- {npc} a une peur bleue des loups depuis l'enfance.
- {npc} craint par-dessus tout de mourir seul{g:|e|·e}.
- {npc} n'ose pas s'aventurer dans la Forêt des Murmures.
- {npc} a peur de la magie et de ceux qui la pratiquent.

### Passe-temps (`hobby`)

- {npc} sculpte de petites figurines de bois le soir.
- {npc} joue aux dés à la taverne, et perd souvent.
- {npc} collectionne les plantes séchées.
- {npc} chante à tue-tête quand {g:il|elle|iel} se croit seul{g:|e|·e}.

### Secret (`secret`)

- {npc} a autrefois volé une bourse au marché, et s'en veut encore.
- {npc} cache une petite fortune sous son plancher.
- {npc} a déserté l'armée du roi il y a des années.
- {npc} écrit des lettres d'amour qu'{g:il|elle|iel} n'envoie jamais.

### Opinion (`opinion`)

- {npc} trouve que les gardes en font trop.
- {npc} se méfie des aventuriers : « Ça porte malheur. »
- {npc} pense que les elfes cachent quelque chose.
- {npc} admire les gens qui travaillent de leurs mains.

---

## Actions de dialogue

### Amical

#### Discuter (`chat`)

- **Catégorie** : amical.
- **Conditions** : aucune.
- **Réussite** : Amitié +4, Confiance +1.

#### Complimenter (`compliment`)

- **Catégorie** : amical.
- **Conditions** : aucune.
- **Réussite** : Amitié +3.

#### Plaisanter (`joke`)

- **Catégorie** : amical.
- **Conditions** : aucune.
- **Test** : Persuasion DD 10.
- **Réussite** : Amitié +6.
- **Échec** : Amitié -2.

#### Se renseigner (`ask_about`)

- **Catégorie** : amical.
- **Conditions** : Amitié 0.
- **Réussite** : Amitié +2, Confiance +1.
- **Effet spécial** : révèle un nouveau fait sur le PNJ (définitif).

### Romantique

#### Flirter (`flirt`)

- **Catégorie** : romantique.
- **Conditions** : Amitié 10, deux adultes.
- **Test** : Persuasion contre la Perspicacité du PNJ.
- **Réussite** : Amour +8, Amitié +1.
- **Échec** : Amour -2, Amitié -2.

#### Proposer de vous fréquenter (`propose_dating`)

- **Catégorie** : romantique.
- **Conditions** : Amour 40, deux adultes.
- **Test** : Persuasion DD 8.
- **Réussite** : devient : en couple, Amour +5.
- **Échec** : Amour -5.

#### Proposer une relation libre (`propose_open`)

- **Catégorie** : romantique.
- **Conditions** : statut : en couple / fiancés / mariés, deux adultes.
- **Test** : Persuasion contre la Perspicacité du PNJ.
- **Réussite** : devient : relation libre.
- **Échec** : Amour -6, Confiance -6.

#### Demander en fiançailles (`propose_engagement`)

- **Catégorie** : romantique.
- **Conditions** : Amour 60, Confiance 40, statut : en couple, deux adultes.
- **Test** : Persuasion DD 10.
- **Réussite** : devient : fiancés, Amour +10.
- **Échec** : Amour -5.

#### Se marier (`marry`)

- **Catégorie** : romantique.
- **Conditions** : Amour 70, statut : fiancés, deux adultes.
- **Réussite** : devient : mariés, Amour +10, Confiance +10, réputation +2.

#### Fonder une famille (`have_child`)

- **Catégorie** : romantique.
- **Conditions** : Amour 70, statut : en couple / fiancés / mariés, deux adultes.
- **Effet spécial** : un enfant naîtra après 270 jours.

#### Rompre (`break_up`)

- **Catégorie** : romantique.
- **Conditions** : statut : en couple / fiancés / mariés.
- **Réussite** : Amour -30, Confiance -20, Amitié -10.
- **Effet spécial** : met fin à la relation (rupture ou divorce).

### Hostile

#### Provoquer (`provoke`)

- **Catégorie** : hostile.
- **Conditions** : aucune.
- **Réussite** : Amitié -5, Confiance -2.

#### Insulter (`insult`)

- **Catégorie** : hostile.
- **Conditions** : aucune.
- **Réussite** : Amitié -10, Confiance -5, réputation -1.

#### Intimider (`intimidate`)

- **Catégorie** : hostile.
- **Conditions** : aucune.
- **Test** : Persuasion (FOR) contre la Perspicacité du PNJ.
- **Réussite** : Confiance -3, Amitié -3, le PNJ vous craint.
- **Échec** : Amitié -5.

### Spécial

#### Échanger (`trade`)

- **Catégorie** : spécial.
- **Conditions** : aucune.
- **Effet spécial** : ouvre la fenêtre d'échange.

#### Proposer de vous accompagner (`recruit`)

- **Catégorie** : spécial.
- **Conditions** : Amitié 60.
- **Effet spécial** : le PNJ rejoint le groupe (selon la classe de son rôle).

#### Communiquer par gestes (`gestures`)

- **Catégorie** : spécial.
- **Conditions** : aucune.
- **Test** : Langues DD 12.
- **Effet spécial** : permet de se comprendre sans langue commune pour le reste de la conversation.

---

## Humeurs

- **radieux** : DD -2, gains ×1.25.
- **de bonne humeur** : DD -1, gains ×1.1.
- **neutre** : DD +0, gains ×1.0.
- **maussade** : DD +1, gains ×0.8.
- **furieux** : DD +3, gains ×0.5.

---

## Décisions (2026-10-13)

- Menu d'actions à la Sims (barre en bas), et commerce / échange à la façon de BG3 (vendre, acheter, offrir,
  demander gratuitement).
- Une interaction terminée fait passer une période de temps.
- Liste des PNJ présents dans un lieu, et possibilité de chercher un garde, un villageois… (généré).
- Jauges Amitié / Amour / Confiance ; pas d'usure pour l'instant ; statuts par seuils.
- Relations entre PNJ dès maintenant (monde autonome) ; traits, goûts et humeur ; faits révélés progressivement.
- Les PNJ se souviennent des actes du héros et des vies passées.
- Tests pour les actions risquées ; Perspicacité passive (humeur, traits cachés) et en opposition.
- Langues cryptées : une lettre par rang.
- Romance sans restriction d'espèce ni de genre ; les PNJ préfèrent certaines actions (traits).
- Étapes : se fréquenter, fiançailles, mariage ; ruptures et divorces ; couples libres et relations polyamoureuses.
- Enfants : naissance après un délai, ils grandissent en PNJ (non jouables).
- Approbation des compagnons ; recrutement par événement ou par amitié.
- Carnet des PNJ ; cadeaux via l'échange ; réputation par ville.

## Questions ouvertes

1. **Rendez-vous et activités** : faut-il des actions longues avec un PNJ (dîner à la taverne, promenade, entraînement)
   qui rapportent plus mais coûtent plus de temps ou d'or ?
2. **Les PNJ prennent-ils l'initiative ?** Un ami qui vient demander un service, un rival qui provoque, un partenaire
   qui se plaint d'être négligé : sous forme d'événements au hub ?
3. **Mort des PNJ** : de vieillesse, en combat, par des événements ? Et le deuil (souvenirs, réputation) ?
4. **Usure des relations** : à réactiver plus tard (avec le temps long) ?
5. **Les enfants du héros** : ils grandissent dans le monde ; faut-il pouvoir les retrouver dans une vie suivante
   (« le fils d'un ancien héros ») ?
6. **Échanges entre PNJ** : les PNJ achètent-ils, se volent-ils, s'offrent-ils des objets entre eux ?
7. **Réputation** : quels effets (prix, gardes plus méfiants, événements) ?
