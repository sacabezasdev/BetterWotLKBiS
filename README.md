# BetterWotLKBiS

BetterWotLKBiS is a World of Warcraft 3.3.5 addon for Wrath of the Lich King
that shows Best in Slot gear lists and alerts the player when a linked chat item
is an upgrade for the current class/spec.

The addon stores Wowhead WotLK item IDs and resolves item names, icons, quality,
and tooltips in-game through the client cache.

## Features

- Compact BiS browser inspired by BisTooltip-style layouts.
- Class, spec, and phase dropdowns.
- Pre-Raid, Phase 1, Phase 2, Phase 3, and Phase 4 lists.
- Up to 6 ranked items per slot.
- Item icons, quality-colored borders, and tooltips.
- Equipped item markers in the BiS browser.
- Chat itemLink scanner for Say, Whisper, Guild, Party, Raid, Raid Warning, and
  custom/global channels.
- Upgrade comparison against currently equipped gear.
- Sound alert plus visual warning when a linked item is better.
- Optional movable center popup with item icon and clickable item link.
- Movable minimap button for quick access.
- Interface/AddOns configuration panel.
- SavedVariables support through `BetterWotLKBiSDB`.

## Commands

- `/bbis`
- `/betterbis`
- `/wotlkbis`

Use any of these commands to open or close the BiS browser.

The minimap button can also be used:

- Left-click opens or closes the BiS browser.
- Right-click opens the addon options.
- Drag moves the button around the minimap.

Additional slash options:

- `/bbis options` opens the Interface/AddOns options panel.
- `/bbis help` prints the basic command help.

## Options

The Interface/AddOns panel exposes:

- Alert channels:
  - Say
  - Whisper
  - Guild
  - Party
  - Raid
  - Custom/global channels
- Center popup on/off.
- Minimap button on/off.
- A button to open the BiS list UI.

## Supported Lists

The current data set covers 10 classes, 31 specs, and 155 class/spec/phase
source entries.

### Death Knight

- Blood Tank
- Frost DPS
- Unholy DPS

### Druid

- Balance
- Feral DPS
- Feral Tank
- Restoration

### Hunter

- Beast Mastery
- Marksmanship
- Survival

### Mage

- Arcane
- Fire
- Frost

### Paladin

- Holy
- Protection
- Retribution

### Priest

- Discipline
- Holy
- Shadow

### Rogue

- Assassination
- Combat
- Subtlety

### Shaman

- Elemental
- Enhancement
- Restoration

### Warlock

- Affliction
- Demonology
- Destruction

### Warrior

- Arms
- Fury
- Protection

## Upgrade Alerts

When an enabled chat channel contains a real WoW item link, the addon extracts
the internal `itemID`, checks the player's detected class/spec, uses the
selected phase's ranked BiS entries for that slot, and compares the link against
the equipped ranked item or items in that slot. Equipped items are valued by
their best known all-phase ranking, so any ranked item from a later phase is
treated as better than any ranked item from an earlier phase.

Exact `itemID` matches are preferred. When linked and equipped items share the
same item name and equipment slot, the addon also compares item level so a
higher-ilvl heroic variant can alert over the normal version while an
equal-or-higher equipped variant suppresses lower links. Plain text item names
and Wowhead URLs are not scanned as item links.

If `ClassLoot` is enabled, BetterWotLKBiS also uses its class/spec star data as
an optional compatibility filter. `ClassLoot` does not replace the Wowhead rank
order, but it can suppress an alert when the linked item is known by ClassLoot
and is not rated for the detected class/spec.

The alert is suppressed when:

- The item is already equipped.
- The item is not present in the selected phase's current class/spec BiS data.
- The current equipped item has an equal or better phase-aware ranking.
- The equipped item in the replacement slot is not ranked in any supported phase.
- ClassLoot knows the linked item but does not rate it for the current class/spec.
- The linked item is an off-hand item but the apparent empty off-hand slot is
  caused by an equipped two-handed weapon.
- The chat channel is disabled in the addon options.
- The current class/spec has no supported list.

## Spec Detection

The addon detects the player class through `UnitClass` and the spec through the
talent tab with the most points spent.

Druid Feral DPS and Feral Tank share the same talent tab in WotLK, so the addon
preserves the manually selected Feral list when the selected class is Druid.

## Data Source

The BiS data was extracted from Wowhead WotLK guide pages referenced in
`dev.md`. Overview pages are used to resolve the phase-specific `bis-gear`
guides, and only item IDs plus short ranking labels are stored in the addon.

## Known Limitations

- `Druid Balance P3` is currently empty because the official Wowhead WotLK/es
  Phase 3 URL redirects to a Classic guide instead of a WotLK guide.
- The addon does not evaluate stat weights dynamically. It follows the rank
  order from the stored Wowhead lists.
- `ClassLoot` is used only as an optional class/spec compatibility signal, not as
  a full gear ranking or stat comparison engine.
- The addon does not parse plain item names, pasted Wowhead URLs, or arbitrary
  text. It scans WoW item links with `|Hitem:...|h[...]|h`.
- In-game item names and icons may appear as placeholders until the client has
  cached the item info.

## Files

- `BetterWotLKBiS.toc` loads the addon for Interface 30300.
- `Data.lua` contains the generated BiS item ID tables and source URLs.
- `Core.lua` contains the UI, chat scanning, item comparison, alerts, and saved
  settings logic.
