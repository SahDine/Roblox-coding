# Steal a Critter 🐾

Un jeu Roblox **complet** du genre « steal & defend tycoon » — le genre qui a explosé en 2025 avec *Steal a Brainrot* et qui reste parmi les plus rentables de la plateforme. Tout est en code (carte, créatures, interface), il suffit de synchroniser le projet dans Roblox Studio avec Rojo.

**La boucle de jeu :**

1. Des créatures défilent sur un tapis roulant central → tu les achètes avec ton argent (ou instantanément en Robux pour les raretés Epic+).
2. Elles marchent jusqu'à ta base et produisent de l'argent chaque seconde sur leur piédestal.
3. Marche sur les dalles vertes pour encaisser, achète des créatures plus rares, recommence.
4. **Vole** les créatures des autres joueurs : maintiens « Steal », porte-la au-dessus de ta tête et ramène-la dans ta base.
5. **Défends** ta base : verrouille-la (laser 60 s) et **gifle** les voleurs pour qu'ils lâchent leur butin.
6. **Renaissance** (Rebirth) : dépense ton argent contre un bonus permanent (+50 % de revenus, +1 emplacement). Tu gardes tes créatures.

---

## Fonctionnalités

| Système | Détails |
|---|---|
| Créatures | 24 créatures inspirées des monstres de poche classiques (noms et modèles originaux), 7 raretés (Common → **Secret**), sculptées en code avec visages expressifs, flammes, ailes, auras ; animation de dandinement / vol |
| Mutations | Gold x2, Diamond x3, Rainbow x5 (couleurs animées), Galaxy x10 |
| Tapis roulant | Chemin enchanté entre deux portails magiques, une créature toutes les 6 s, ~100 s pour le traverser, annonces serveur pour les raretés Legendary+, achat au premier arrivé |
| Bases | 8 petits châteaux (1 par joueur) : remparts, tours à dôme, drapeaux, torches, bouclier magique, grille 4×4 de piédestaux lumineux, dalles d'encaissement, panneau au nom du propriétaire |
| Carte | Monde fantasy généré en terrain : prairie, place pavée, chemins, étangs, collines, champignons géants lumineux, cristaux, arbres magiques, îles flottantes avec cascades, lucioles, fontaine magique au spawn |
| Vol | Prompt à maintenir, transport au-dessus de la tête, vitesse réduite, faisceau vers ta base, délai max 60 s |
| Défense | Verrou laser (le propriétaire passe, les autres sont bloqués), gant de gifle avec recul |
| Progression | Renaissances, emplacements débloquables, gains hors-ligne (25 % pendant 3 h max) |
| Rétention | Récompense quotidienne sur 7 jours (avec série), codes promo, bonus d'amis (+10 % par ami), bonus Premium |
| Interface | HUD (argent, revenus, emplacements), boutique à onglets, renaissance, daily, codes, notifications, adaptée mobile |
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
| `MegaSlap` | Mega Slap | Gant doré : gros recul et grande portée | 99 R$ |

### Developer products (achats répétables)

| Clé | Effet | Prix suggéré |
|---|---|---|
| `CashSmall` / `CashMedium` / `CashLarge` / `CashHuge` | Argent = max(montant fixe, X minutes de ton revenu) → restent intéressants toute la partie | 25 / 79 / 199 / 449 R$ |
| `ServerLuck` | **Chance x2 pour tout le serveur** pendant 15 min (cumulable) — achat très « social » | 99 R$ |
| `BaseLock` | Verrouille ta base 5 minutes | 39 R$ |
| `UnitEpic` / `UnitLegendary` / `UnitMythic` / `UnitSecret` | Achat instantané de la créature du tapis sur laquelle tu cliques (touche F), ou créature aléatoire de cette rareté depuis la boutique | 49 / 99 / 249 / 499 R$ |

Bonus intégrés pour la conversion : annonces serveur quand quelqu'un achète, rubans « POPULAR » / « BEST VALUE », prix Robux affichés directement sur les créatures du tapis.

### Activer la monétisation

1. Publie le jeu (voir *Installation*).
2. Dans le [Creator Dashboard](https://create.roblox.com/dashboard/creations) → ton expérience → **Monetization** :
   - **Passes** : crée les 5 game passes, mets-les en vente.
   - **Developer Products** : crée les 10 produits.
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

Si l'accès aux API n'est pas activé, le jeu bascule automatiquement sur des données temporaires en Studio. Les achats Robux en Studio sont des **achats de test gratuits** (une fois les IDs configurés). Pour tester le vol, lance **Test → Clients and Servers** avec 2 joueurs.

---

## Équilibrage

Tout se règle sans toucher au code des systèmes :

| Fichier | Contenu |
|---|---|
| [`GameConfig.luau`](src/shared/Config/GameConfig.luau) | Argent de départ, vitesse du tapis, coût des renaissances, vol, verrou, gifle, daily, **codes promo** |
| [`Units.luau`](src/shared/Config/Units.luau) | Les créatures : prix, revenus, couleurs |
| [`CritterDesigns.luau`](src/server/Modules/CritterDesigns.luau) | La forme 3D de chaque créature |
| [`Rarities.luau`](src/shared/Config/Rarities.luau) | Probabilités d'apparition et effets par rareté |
| [`Mutations.luau`](src/shared/Config/Mutations.luau) | Chances et multiplicateurs des mutations |
| [`Monetization.luau`](src/shared/Config/Monetization.luau) | IDs et contenu des passes / produits |

Équilibrage actuel : une créature est rentabilisée en 25 s (Common) à 200 s (Secret). Avec la chance normale, une Legendary apparaît toutes les ~3 min, une Mythic toutes les ~12 min et une Secret toutes les ~70 min (deux fois plus souvent avec le boost x2).

Pour ajouter une créature : ajoute une ligne dans `Units.luau`, puis (optionnel) sculpte-la dans `CritterDesigns.luau` avec les outils de `CritterBuilder` (ellipsoïdes, membres, yeux, joues, flammes, particules…). Sans design dédié, elle utilise un modèle générique.

Les créatures ont des noms originaux : utiliser les vrais noms ou les designs exacts d'une licence (Pokémon…) dans un jeu monétisé expose à une suppression pour violation de droits d'auteur. Si tu renommes une créature, ajoute l'ancien nom dans `Units.Aliases` pour que les sauvegardes des joueurs soient converties.

### Modèles personnalisés

Pour remplacer le modèle généré d'une créature par ton propre modèle 3D : crée `ReplicatedStorage/Assets/Critters/<Nom exact de la créature>` (un `Model` contenant une pièce nommée `HumanoidRootPart`). Le jeu l'utilisera automatiquement et calculera la hauteur au sol.

---

## Architecture

```
src/
├── shared/                 → ReplicatedStorage.Shared (serveur + client)
│   ├── Config/             GameConfig, Units, Rarities, Mutations, Monetization
│   ├── Economy.luau        formules (revenus, prix, renaissance, packs)
│   ├── Remotes.luau        accès typé aux RemoteEvents / RemoteFunctions
│   └── Util/               Format (1.2K, 3.4M...), Signal
├── server/                 → ServerScriptService.Server
│   ├── Main.server.luau    démarrage + cycle de vie joueur (ordre garanti)
│   ├── Services/           Data, Map, Plot, Unit, Conveyor, Steal, Combat,
│   │                       Monetization, Boost, Currency, Rebirth, Reward
│   └── Modules/            CritterBuilder + CritterDesigns (modèles), UnitModelBuilder,
│                           Decor (accessoires fantasy), Walker, Notifier
└── client/                 → StarterPlayerScripts.Client
    ├── Main.client.luau
    ├── Controllers/        HUD, Store, Rebirth, Daily, Codes, Notifications, World
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
