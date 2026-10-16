# Steal a Critter 🐾

Un jeu Roblox **complet** du genre « steal & defend tycoon » — le genre qui a explosé en 2025 avec *Steal a Brainrot* et qui reste parmi les plus rentables de la plateforme. Tout est en code (carte, créatures, interface), il suffit de synchroniser le projet dans Roblox Studio avec Rojo.

**La boucle de jeu :**

1. Des créatures défilent sur un tapis roulant central → tu les achètes avec ton argent (ou instantanément en Robux pour les raretés Epic+). Les **Legendary, Mythic et Secret** arrivent à heure fixe : un grand panneau public affiche le compte à rebours.
2. Elles marchent jusqu'à ta base (une à la fois : attends qu'elle soit posée pour en acheter une autre) et produisent de l'argent chaque seconde sur leur piédestal.
3. Touche les piédestaux d'encaissement lumineux pour récupérer l'argent, achète des créatures plus rares, **améliore ta base**, recommence.
4. **Vole** les créatures des autres joueurs : maintiens « Steal », porte-la au-dessus de ta tête et ramène-la dans ta base.
5. **Défends** ta base : verrouille-la (bouclier de 60 s, jusqu'à 105 s avec les améliorations) et **gifle** les voleurs avec ta grande main pour qu'ils lâchent leur butin.
6. **Évolution** : une créature posée dans ta base gagne de l'expérience ; quand son minuteur 🧬 arrive à zéro, fais-la évoluer (touche **E**) contre une partie du prix de sa forme suivante. Elle rapporte alors beaucoup plus.
7. **Renaissance** (Rebirth) : dépense ton argent contre un bonus permanent (+50 % de revenus, +1 emplacement). Tu gardes tes créatures.

---

## Fonctionnalités

| Système | Détails |
|---|---|
| Créatures | **48 créatures** inspirées des monstres de poche classiques (noms et modèles originaux), 7 raretés (Common → **Secret**), modélisées en code dans un style **low poly 100 % triangles** (aucune face plate ; seuls les yeux et la bouche sont ronds), flammes, ailes, auras |
| Animations | Chaque créature a un squelette (jambes, bras, tête, oreilles, queue, ailes, nageoires) : **marche** quand elle se déplace (jambes et bras en opposition, corps qui rebondit) et **idle** à l'arrêt (respiration, regard, queue qui remue, oreilles qui frémissent). Les créatures volantes **planent** et battent des ailes |
| Évolution | 16 familles d'évolution (2 ou 3 formes, ex. Sproutle → Bloomtoad → Floradon). L'XP monte de 1/s quand la créature est posée dans ta base (garde son XP si elle est volée). Durée selon la rareté de la forme suivante (1 min 30 → 1 h), coût = 50 % du prix de la forme suivante, mutation conservée, effet visuel + annonce serveur dès Epic |
| Mutations | Gold x2, Diamond x3, Rainbow x5 (couleurs animées), Galaxy x10 |
| Tapis roulant | Chemin enchanté entre deux portails magiques, une créature toutes les 6 s, ~100 s pour le traverser, achat au premier arrivé, une seule créature en route vers ta base à la fois |
| Raretés à heure fixe | Legendary toutes les 8 min, Mythic toutes les 25 min, Secret toutes les 60 min (2x plus vite avec la chance serveur), compte à rebours public sur le panneau « RARE CRITTERS » près du portail, annonces serveur |
| Bases | 8 châteaux (1 par joueur) sur une plateforme de pierre avec rampe, remparts, tours, bouclier magique, grille 4×4 de piédestaux, **piédestaux d'encaissement** lumineux (vert quand de l'argent attend), panneau au nom du propriétaire |
| Amélioration de base | 10 niveaux (de 1K à 100M) : +10 % de revenus par niveau (x1,9 au niveau 10), +5 s de bouclier par niveau, et le château change d'apparence pour tout le monde : Stone Keep → Royal Castle (niv. 4) → Crystal Citadel (niv. 7) → Golden Palace (niv. 10). Conservé après une renaissance |
| Carte | Monde fantasy low poly : prairie, place pavée, étangs, arbres et rochers à facettes, cristaux, champignons géants, îles flottantes, montagnes à l'horizon, fontaine au spawn, portails « NEW CRITTERS » / « BYE BYE » |
| Classements mondiaux | Deux panneaux près du spawn : **TOP REBIRTHS** et **TOP MONEY** (argent gagné au total), top 10 mondial mis à jour toutes les 2 min |
| Vol | Prompt à maintenir, transport au-dessus de la tête, vitesse réduite, faisceau vers ta base, délai max 60 s |
| Défense | Bouclier (le propriétaire passe, les autres sont bloqués), **grande main de gifle** low poly avec animation du bras de droite à gauche (vue par tous), recul |
| Progression | Renaissances, emplacements débloquables, gains hors-ligne (25 % pendant 3 h max) |
| Rétention | Récompense quotidienne sur 7 jours façon simulateurs Roblox (petit jour 1, gros saut au jour 2, créature Epic au jour 7), codes promo, bonus d'amis (+10 % par ami), bonus Premium, classements mondiaux |
| Interface | HUD (argent, revenus, emplacements), boutique à onglets, amélioration de base, renaissance, daily, codes, notifications, adaptée mobile ; caméra limitée (dézoom max 64) |
| Sauvegarde | DataStore avec verrou de session (anti-duplication), sauvegarde auto, à la sortie et à l'arrêt du serveur |

---

## Monétisation 💰

Ce sont les mécaniques qui rapportent le plus dans ce genre de jeu en ce moment.

### Game passes (achat unique)

| Clé | Nom | Effet | Prix suggéré |
|---|---|---|---|
| `VIP` | VIP | Argent x2 à vie + tag [VIP] dans le chat | 249 R$ |
| `AutoCollect` | Auto Collect | L'argent arrive directement dans le portefeuille | 149 R$ |
| `ExtraSlots` | +4 Slots | 4 piédestaux en plus | 199 R$ |
| `FastSteal` | Fast Thief | Vol 2x plus rapide + plus rapide en portant | 179 R$ |
| `FastEvolve` | Fast Evolution | Les créatures évoluent 2x plus vite | 149 R$ |
| `MegaSlap` | Mega Slap | Gant doré : gros recul et grande portée | 99 R$ |

### Developer products (achats répétables)

| Clé | Effet | Prix suggéré |
|---|---|---|
| `CashSmall` / `CashMedium` / `CashLarge` / `CashHuge` | Argent = max(montant fixe, X minutes de ton revenu) → restent intéressants toute la partie | 25 / 79 / 199 / 449 R$ |
| `ServerLuck` | **Chance x2 pour tout le serveur** pendant 15 min (cumulable) : meilleures chances sur le tapis et minuteurs Legendary / Mythic / Secret 2x plus rapides — achat très « social » | 99 R$ |
| `BaseLock` | Verrouille ta base 5 minutes | 39 R$ |
| `InstantEvolve` | Rend immédiatement prête à évoluer la créature de ta base sur laquelle tu appuies (touche **F**, « Ready now ») | 39 R$ |
| `UnitEpic` / `UnitLegendary` / `UnitMythic` / `UnitSecret` | Achat instantané de la créature du tapis sur laquelle tu cliques (touche F), ou créature aléatoire de cette rareté depuis la boutique | 49 / 99 / 249 / 499 R$ |

Bonus intégrés pour la conversion : annonces serveur quand quelqu'un achète, rubans « POPULAR » / « BEST VALUE », prix Robux affichés directement sur les créatures du tapis.

### Activer la monétisation

1. Publie le jeu (voir *Installation*).
2. Dans le [Creator Dashboard](https://create.roblox.com/dashboard/creations) → ton expérience → **Monetization** :
   - **Passes** : crée les 6 game passes, mets-les en vente.
   - **Developer Products** : crée les 11 produits.
3. Copie chaque **ID** dans [`src/shared/Config/Monetization.luau`](src/shared/Config/Monetization.luau) (champ `Id = 0` → `Id = 123456789`).

Un `Id = 0` signifie « pas configuré » : la boutique affiche *Not set up* et rien ne peut être acheté. Le prix affiché en jeu est lu directement chez Roblox, il est donc toujours exact.

> **Règles Roblox** : les produits « créature aléatoire » de la boutique sont des *paid random items* — les probabilités sont affichées sur chaque carte avant l'achat, comme l'exige Roblox. Les achats depuis le tapis sont déterministes (tu reçois exactement la créature cliquée). Pense aussi à remplir le questionnaire de maturité de l'expérience.

Les achats suivent le modèle recommandé par Roblox : chaque `PurchaseId` est enregistré dans les données du joueur, `PurchaseGranted` n'est renvoyé qu'après une sauvegarde réussie, jamais de double attribution.

---

## Installation

### 1. Outils

- [Roblox Studio](https://create.roblox.com/)
- [Rokit](https://github.com/rojo-rbx/rokit) puis, dans ce dossier : `rokit install` (installe Rojo et StyLua aux versions du projet)
- Le plugin Rojo pour Studio : `rojo plugin install`

### 2. Ouvrir le jeu dans Studio

**Option A — synchronisation en direct (recommandé pour développer)**

```bash
rojo serve
```

Ouvre un nouveau *Baseplate* dans Studio → onglet **Plugins** → **Rojo** → **Connect**.

**Option B — générer un fichier .rbxl**

```bash
rojo build -o StealACritter.rbxl
```

puis ouvre `StealACritter.rbxl` dans Studio.

La carte est générée au lancement du serveur (le *Baseplate* par défaut est supprimé automatiquement). Clique sur **Play** pour tester.

### 3. Publier

1. **File → Publish to Roblox**.
2. **Game Settings → Security** : active *Enable Studio Access to API Services* (sauvegardes en Studio).
3. Règle le **nombre maximum de joueurs à 8** (une base par joueur) : *Game Settings → Places* dans Studio, ou la page *Places* de l'expérience dans le Creator Dashboard.
4. Configure la monétisation (voir plus haut), puis rends le jeu public.

---

## Tester en Studio

Dans [`src/shared/Config/GameConfig.luau`](src/shared/Config/GameConfig.luau), section `Debug` (n'a aucun effet en ligne) :

| Option | Effet |
|---|---|
| `UseMockDataInStudio = true` | Données en mémoire (rien n'est sauvegardé) |
| `GrantAllPassesInStudio = true` | Tu possèdes tous les game passes |
| `StudioStartingCash = 1e9` | Commence avec beaucoup d'argent |

Touches sur tes créatures : **E** évoluer, **X** vendre, **F** évolution instantanée (Robux). Sur les créatures des autres : maintenir **E** pour voler. Améliorer ta base : bouton **🏰 Upgrade** du HUD ou l'autel près de l'entrée de ta base.

Les classements mondiaux ne s'affichent qu'en ligne (ou en Studio avec l'accès aux API activé) ; sinon les panneaux indiquent « LEADERBOARD OFFLINE ». Les sessions Studio n'envoient jamais de scores.

Si l'accès aux API n'est pas activé, le jeu bascule automatiquement sur des données temporaires en Studio. Les achats Robux en Studio sont des **achats de test gratuits** (une fois les IDs configurés). Pour tester le vol, lance **Test → Clients and Servers** avec 2 joueurs.

---

## Équilibrage

Tout se règle sans toucher au code des systèmes :

| Fichier | Contenu |
|---|---|
| [`GameConfig.luau`](src/shared/Config/GameConfig.luau) | Argent de départ, vitesse du tapis, **minuteurs des raretés** (`RareSpawns`), coût des renaissances, **améliorations de base** (`BaseUpgrade` : coûts, bonus, apparences), vol, verrou, gifle, **évolution** (durées, coût), daily, classements, **codes promo** |
| [`Units.luau`](src/shared/Config/Units.luau) | Les créatures : prix, revenus, couleurs, évolution (`EvolvesTo`) |
| [`CritterDesigns/`](src/server/Modules/CritterDesigns) | La forme 3D et le squelette de chaque créature, rangés par famille (Starters, WaterAndGhosts, DragonsAndRocks, Companions, Fighters, Legends) |
| [`Rarities.luau`](src/shared/Config/Rarities.luau) | Probabilités d'apparition et effets par rareté |
| [`Mutations.luau`](src/shared/Config/Mutations.luau) | Chances et multiplicateurs des mutations |
| [`Monetization.luau`](src/shared/Config/Monetization.luau) | IDs et contenu des passes / produits |

Équilibrage actuel : une créature est rentabilisée en 20 s (Common) à 200 s (Secret). Le tapis tire au hasard les Common → Epic (une Epic toutes les ~75 s) ; les Legendary arrivent toutes les 8 min, les Mythic toutes les 25 min et les Secret toutes les 60 min (deux fois plus vite avec le boost x2). Récompenses quotidiennes : 50 $ le jour 1, 400 $ le jour 2 … 8 000 $ + une Epic le jour 7 (ou quelques minutes de revenus si c'est plus).

Pour ajouter une créature : ajoute une ligne dans `Units.luau` (avec `EvolvesTo = "Nom"` si elle évolue), puis (optionnel) modélise-la dans un fichier de `CritterDesigns/` avec les outils de `CritterBuilder` (tout est en triangles : `Ball` à facettes, `Limb`, `Chain`, `Cone`, `Spike`, `Blade`, `Tri` ; yeux et bouche ronds avec `Eyes` / `Mouth`) et donne-lui des os (`Bone` / `MirrorBone` : jambes, bras, tête, queue, ailes…) pour qu'elle soit animée. Le design de `Zappip` sert d'exemple. Sans design dédié, elle utilise un modèle générique.

Les créatures ont des noms originaux : utiliser les vrais noms ou les designs exacts d'une licence (Pokémon…) dans un jeu monétisé expose à une suppression pour violation de droits d'auteur. Si tu renommes une créature, ajoute l'ancien nom dans `Units.Aliases` pour que les sauvegardes des joueurs soient converties.

### Modèles personnalisés

Pour remplacer le modèle généré d'une créature par ton propre modèle 3D : crée `ReplicatedStorage/Assets/Critters/<Nom exact de la créature>` (un `Model` contenant une pièce nommée `HumanoidRootPart`). Le jeu l'utilisera automatiquement et calculera la hauteur au sol.

---

## Architecture

```
src/
├── shared/                 → ReplicatedStorage.Shared (serveur + client)
│   ├── Config/             GameConfig, Units, Rarities, Mutations, Monetization
│   ├── Economy.luau        formules (revenus, prix, renaissance, packs, évolution, améliorations de base)
│   ├── CritterPose.luau    courbes d'animation des créatures (marche, idle, vol)
│   ├── Remotes.luau        accès typé aux RemoteEvents / RemoteFunctions
│   └── Util/               Format (1.2K, 3.4M...), Signal
├── server/                 → ServerScriptService.Server
│   ├── Main.server.luau    démarrage + cycle de vie joueur (ordre garanti)
│   ├── Services/           Data, Map, Plot, Unit, Conveyor, Steal, Combat,
│   │                       Monetization, Boost, Currency, Rebirth, Reward,
│   │                       Upgrade (améliorations de base), Leaderboard (classements mondiaux)
│   └── Modules/            LowPoly (géométrie en triangles), CritterBuilder + CritterDesigns/
│                           (modèles + squelettes), UnitModelBuilder, Decor / Flora / Landmarks /
│                           Horizon (décor low poly), Walker, Notifier
└── client/                 → StarterPlayerScripts.Client
    ├── Main.client.luau
    ├── Controllers/        HUD, Store, Rebirth, Daily, Codes, Notifications, World,
    │                       CritterAnimation, Slap, Upgrade, Boards (compte à rebours des raretés)
    └── UI/UIKit.luau       composants d'interface
```

**Sécurité** : le serveur fait autorité sur tout (argent, achats, vols, distances, durée de maintien des prompts, limites d'appels des remotes). Le client ne fait qu'afficher.

---

## Pour aller plus loin (live ops)

Les jeux de ce genre vivent de mises à jour régulières :

- ajouter de nouvelles créatures chaque semaine (une ligne dans `Units.luau`) ;
- publier un nouveau code promo à chaque mise à jour (`GameConfig.Codes`) ;
- organiser des événements « chance x2 » le week-end (`BoostService.AddServerLuck`) ;
- faire apparaître une créature précise pour un événement (`ConveyorService.SpawnCritter`) ;
- tester différents prix avec l'outil *Price Optimization* du Creator Dashboard.
