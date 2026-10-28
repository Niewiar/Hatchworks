# Hatchworks

## Hatchworks Database

Open the **Database** tab above the main viewport or **Project > Tools > Hatchworks Database**.
The addon is enabled in Project Settings > Plugins. Its interface is authored in `addons/hatchworks_database/database_panel.tscn` and reusable field/preview scenes.

- Select a catalog and search by name or stable ID.
- Double-click a table cell or use the detail fields to edit values.
- Ctrl/Shift selects multiple rows. Choose a numeric field and multiplier to apply a bulk change.
- New and Duplicate create independent definitions. Browse assigns scenes, textures, materials or mesh variants.
- Save All validates the catalog and saves native `.tres` resources. Start a new game to apply balance changes.
- Undo/Redo work across edits, bulk changes, creation and removal. A saved removal can also be undone and saved again.
- Remove is blocked for definitions used elsewhere and built-in resource roles. Reload discards unsaved panel changes and reads disk.
- Saving is blocked if a watched definition changed on disk. Reload first to avoid overwriting external edits.

The runtime catalog is `resources/database/game_database.tres`. Flora and fence definitions keep their existing locations. New definitions are created below `resources/database/`.
Built-in resource numeric IDs are stable: 0 grass, 2 moss, 3 sand, 4 ground rock, 5 plant fiber, 6 herbs, 9 wood, 10 stone. IDs 1, 7 and 8 are reserved. Grass, shrubs and reeds yield Plant Fiber; their growth and habitat settings remain independent. Additional item resources receive new IDs and appear in the inventory HUD.
Creature scene instances use `Creature.species_id` to select their definition. Only implemented handling parameters are exposed; needs and production will be added with those gameplay systems.
Habitat moisture/shade use 0–1, slope is rise/run, and water depth is positive below water and negative above it. Bounds are exclusive.
Tree harvesting permanently removes the tree. Plant throughput estimates assume suitable habitat and harvesting at 60% growth. Fence estimates assume 32 terrain pixels per meter.

Working files and verification projects are stored outside the game in `../Hatchworks-workbench/`.
