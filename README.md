<h1 align="center">BuffReminders</h1>
<p align="center">
  <img src="https://github.com/zerbiniandrea/BuffReminders/blob/main/images/logo.png?raw=true" width="180" />
</p>
<p align="center">
  <a href="https://github.com/zerbiniandrea/BuffReminders"><img src="https://shields.io/badge/github-gray?logo=github&style=for-the-badge&logoColor=white" /></a>
  <a href="https://discord.gg/qezQ2hXJJ7"><img src="https://shields.io/badge/discord-5865F2?logo=discord&style=for-the-badge&logoColor=white" /></a>
</p>
<p align="center">Track missing buffs at a glance</p>
<p align="center">From the author of <a href="https://wago.io/iWkZ4Eq-i">Raid Buffs Tracker</a>, one of the most popular raid buffs tracking WeakAuras.</p>

<p align="center">
  <img src="https://github.com/zerbiniandrea/BuffReminders/blob/main/images/buffs.png?raw=true" />
</p>

Check what buffs you or your party are missing, and easily click to cast them!
Supports consumables, pets, and more. Add custom buffs to track whatever you want.

<p align="center">
  <img src="https://github.com/zerbiniandrea/BuffReminders/blob/main/images/buffs-split-groups.png?raw=true" />
</p>

## Configuration

Type `/br` to open the options panel.
Choose which buffs you want to track and how you want them to look.

<p align="center">
  <img src="https://github.com/zerbiniandrea/BuffReminders/blob/main/images/settings-buffs.png?raw=true" />
</p>

<p align="center">
  <img src="https://github.com/zerbiniandrea/BuffReminders/blob/main/images/settings-options.png?raw=true" />
</p>

## Limitations

- **Buff counts** only include group members who are alive, connected, visible (not phased), and allied. Dead, offline, or phased players are excluded. In open world, opposing-faction players are not counted.
- **Spec-aware filtering** - buffs like Intellect and Attack Power are filtered by specialization (e.g., Feral Druids won't be counted as missing Intellect). Spec data is shared between group members via [LibSpecialization](https://www.curseforge.com/wow/addons/libspecialization), which is bundled with BuffReminders and other popular addons like BigWigs, so most of your group likely already has it. When spec info is unavailable (solo play, ally hasn't broadcasted yet, or unknown/starter specs), filtering falls back to class-level.

## Support

Got a bug to report, a feature idea, or just want to see what's coming next? Join the [Discord](https://discord.gg/qezQ2hXJJ7)!

## Credits

Huge thanks to [Time Spiral Tracker](https://www.curseforge.com/wow/addons/time-spiral-tracker) for the idea of using action bar spell glows to detect missing buffs.

Huge thanks to [plusmouse](https://plusmouse.com/) (author of [Platynator](https://www.curseforge.com/wow/addons/platynator), [Auctionator](https://www.curseforge.com/wow/addons/auctionator), and more) for the clean, well-organized code that helped me learn WoW addon development patterns.
