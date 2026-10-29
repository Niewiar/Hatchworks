# Hatchworks

## First creature

A new game begins on flat, bare soil with one placed Incubator, no egg and zero of every resource. The Incubator unlocks Life immediately. Further Incubators remain available in Build and cost 5 Wood, 10 Stone and 5 Plant Fiber. Invalid sites spend nothing.

Soil and Life are the initial discoveries. Sculpt a pond with Lower to reveal and discover Water. Open Discoveries using the book button. Drag cards onto the board and onto each other, hold LMB to carry a card with the cursor and release it on the board or another card. Discovered concepts are reusable and combining them consumes no resources. Only the first discovery of a result grants its item reward. The Discover tab contains the combination board. The Discoveries tab lists known concepts and combinations. Discovery cards have no tooltips. New concepts have an exclamation mark until a card for that concept is hovered; seen state is shared between the catalog, board and discovery archive.

The shortest starter chain is Soil + Life → Seed; Seed + Life → Tuftling Egg. Alternative recipes remain: Soil + Water → Mud; Mud + Soil → Seed; Seed + Water → Grass; Grass + Life → Tuftling Egg. The egg discovery grants one owned egg. Grass + Grass → Plant Fiber; Plant Fiber + Soil → Feeder. Discovering the Feeder grants one construction kit, so the first Feeder can be built without resources. Further Feeders cost 3 Wood and 2 Plant Fiber. Building an Incubator discovers Life; the Incubator is not a discovery card. Gathering resources and creature-sown grass feed into the same discovery catalog.

Click a built Incubator with tools turned off. Its selector lists only owned eggs. Starting incubation consumes exactly one egg, takes 30 seconds by default and cannot be started twice. When ready, click Hatch. The breakable shell reveal leads to the creature information card; Accept spawns one Tuftling beside the Incubator. There are no automatic replacement eggs or resource purchases in this flow.

A Tuftling has its own sex and starts with full satiety. Satiety decreases continuously; the default full-to-empty duration is 240 seconds. Below 35%, it seeks a stocked Feeder when one is reachable. At zero, it stops production and may only seek and eat food. It finds reachable water, bathes, walks to free dry soil and shakes to create grassy ground and grass tufts. Gathering mature tufts yields Plant Fiber and preserves the grassy ground. Click a Feeder to transfer available Plant Fiber into its storage. Hungry Tuftlings walk to a reachable feeding spot, eat one meal and restore 60 percentage points of satiety. Fences block these routes. Food is consumed only after eating completes; empty or submerged Feeders cannot feed creatures. A brass SupplyInput marker marks the future transport connection.

World Balance's natural start option is disabled. Optional natural generation creates terrain, plants and deposits once. Sculpting does not spawn flora. Newly sown plants mature and can be harvested; harvested plants do not regrow by themselves. Players can sculpt, gather plants, chop trees and mine rocks. There is no moss, moisture simulation, ground painting or ground harvesting.

The stone incubator has a brass heat inlet on its side. The scene's HeatInput marker gives the future heating pipe connection point and its outward orientation. Its base is a continuous low stone disc with a rounded edge. The three stone supports have rounded caps and smooth shading.

Incubator surfaces use a material atlas developed from the selected stone incubator concept: grey weathered rock with decorative greenery, chestnut wood, aged brass and green bedding. Each mesh component has its own UV mapping; the three standing stones use different texture offsets. UV2 preserves baked contact occlusion and edge data. Rounded brass and foliage parts use smooth normals; the shader keeps subtle edge wear without deriving bump from albedo. Texture prompts and offline UV tools stay in the workbench.

Egg models use an EggShell root with separately shaped rigid shell fragments and a crack overlay. The default egg has 27 curved pieces with shell thickness, inner surfaces and convex collision shapes. Cracks appear before the fragments detach, tumble and land on the presentation floor. The reveal keeps its black backdrop and clears the fragments after acceptance.

## Controls and inspection

- Build opens structure placement; the incubator is selected from its upper row. LMB places a valid preview.
- With tools turned off, a short LMB click on a creature opens its information panel and focuses the camera. Hold LMB for 0.22 seconds or drag to pick it up. Release to drop it without opening the panel.
- Click a built incubator to open its panel. There is no inspection mode, region overlay or flora/deposit information panel.
- RMB closes the camera focus. With no focus, hold RMB to pan. Hold MMB to orbit around the Y axis. Scroll zooms, or adjusts brush size in brush modes.
- The bag button toggles Inventory, showing resources, owned eggs and construction kits. Counts belong to Inventory, while discovery cards represent reusable concepts without quantities. Hatching a Tuftling does not create a creature discovery node.
- The book button toggles Discoveries. Its centered window leaves the base toolbar accessible. Hold LMB to carry cards from the exact grabbed point; release one over another to combine. RMB removes a card from the board without forgetting the discovery or spending an item. The book button pulses for new discoveries received outside the panel, until the panel is opened. There is no tutorial overlay or close button.
- Underlined keywords and habitat/food icons use the shared custom tooltip scenes.

## Hatchworks Database

Open the **Database** tab above the main viewport or **Project > Tools > Hatchworks Database**. The addon is enabled in Project Settings > Plugins. Its interface is authored in scene files below `addons/hatchworks_database/`.

- Catalogs cover discoveries, combination recipes, creatures, eggs, flora, resources, deposits, fences, buildings, glossary terms and world balance.
- Creature definitions control movement, bathing, shaking, resting, grass output, food, satiety duration, feeding threshold and satiety restored by a meal. Egg definitions control species, breakable shell model and incubation duration. Discovery definitions control one-time item rewards. Recipes reference discovery IDs and work in either ingredient order. Building definitions include unlock discoveries, kit items and feeder storage capacity.
- Glossary terms provide shared keyword and icon descriptions. The Tuftling's habitat is reachable water and free dry soil.
- Search by name or stable ID. Edit cells or detail fields; Ctrl/Shift selects rows for bulk numeric changes. New and Duplicate create independent definitions.
- Save All validates native `.tres` resources. Undo/Redo supports edits, creation and removal. Remove protects referenced definitions. Reload discards unsaved changes. Saving is blocked when a watched file changed outside the panel.
- Start a new game to apply database changes.

The runtime catalog is `resources/database/game_database.tres`. Flora and fence definitions keep their existing locations. New definitions are created below `resources/database/`.

Built-in resource IDs remain stable: 5 Plant Fiber, 6 herbs, 9 wood and 10 stone. IDs 0, 1, 2, 3, 4, 7 and 8 are reserved. Resource quantities are measured in items. Terrain types are separate from inventory resources.

Flora habitat uses slope (rise/run), water depth (positive below water, negative above it) and an optional ground material. Growth rate affects only newly sown plants. Tree and deposit harvesting removes them permanently. Fence estimates assume 32 terrain pixels per meter.

Working files, model builders, backups and verification projects stay outside the game in `../Hatchworks-workbench/`.

UI icons are 64×64 transparent PNGs with matching line work and padding. Toolbar glyphs fit within 56×56 Controls. Disabled building buttons retain their circular frames.

Notifications stack at the bottom right, with at most ten entries and scrolling on short screens. Click a discovery notification to open Discoveries; item and resource notifications open Inventory. Entering either panel clears all notifications assigned to it, while notifications for other panels remain. The X dismisses only that notification. The oldest entry is removed when the limit is reached. New discoveries do not create notifications while Discoveries is open; item and resource arrivals do not create notifications while Inventory is open. Notifications hide during hatching. The book continues to pulse for unread discoveries.

In Database → Recipes, select a row and choose Ingredient A, Ingredient B and Result from named lists with icons. + New opens a recipe composer; duplicate ingredient pairs are rejected in either order. Save All persists the definitions and Undo/Redo includes recipe edits and creation. In Discoveries, Created by / Used in lists show related recipes; double-click one to edit it, or use + Recipe to prefill that discovery as a result. First-discovery reward items are also selected from a list.

Panel sizing belongs to the Control scenes: PanelContainer, MarginContainer, native scrolling and flow containers fit their contents. Tooltip scenes have separate button and description layouts; TooltipController positions them above their anchor or beside the cursor without changing their sizes or wrapping settings.
