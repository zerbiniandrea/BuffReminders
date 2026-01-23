<h1 align="center">RaidBuffsTracker</h1>
<p align="center">
  <img src="https://github.com/user-attachments/assets/1a8775c7-d9ff-41c6-8bab-6f26d75dceab" width="180" />
</p>
<p align="center">
  <a href="https://discord.com/users/285458497020362762"><img src="https://shields.io/badge/discord-5865F2?logo=discord&style=for-the-badge&logoColor=white" /></a>
  <a href="https://github.com/zerbiniandrea/RaidBuffsTracker"><img src="https://shields.io/badge/github-gray?logo=github&style=for-the-badge&logoColor=white" /></a>
</p>
<p align="center">A lightweight World of Warcraft addon that tracks missing raid buffs with a clean icon display.</p>
<p align="center">From the author of <a href="https://wago.io/iWkZ4Eq-i">Raid Buffs Tracker</a>, one of the most popular raid buffs tracking WeakAuras.</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/b8f38780-19bb-4435-badf-705cc585d024" />
</p>

## Features

- Visual buff tracking - Shows buff icons with count overlay (e.g., "17/20" = 17 buffed out of 20)
- Auto-hide - Icons disappear when everyone has the buff
- Draggable frame - Position anywhere on screen, with configurable grow direction
- Class reminder - Shows "BUFF!" under your class's buff icon when party members are missing it
- Smart filtering - Show only in group, hide buffs without provider, show only your class buff
- Class benefit filtering - Only show buffs that benefit your class (BETA)
- Customizable - Adjust icon size, spacing, and text size

## Configuration

To open the options panel, type `/rbt`

<p align="center">
  <img src="https://github.com/user-attachments/assets/d06c09c3-a2d4-474e-a5fb-7d5857d60a07" />
</p>

## Notes

- Due to WoW API limitations, the addon only works out of combat.
- Spec-level filtering (e.g., excluding Feral Druids from Intellect) is not supported because it requires inspect requests which are rate-limited and too heavy.
