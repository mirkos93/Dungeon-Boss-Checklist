# Dungeon Boss Checklist (WoW Classic Era)

<p align="center">
  <img src="icon.png" width="128" />
</p>

**Dungeon Boss Checklist** is a lightweight, automated tracking tool for World of Warcraft Classic Era. It automatically detects when you enter a dungeon or raid and displays a clean, interactive checklist of all bosses available in that instance.

Stop wondering *"Did we kill that optional boss?"* or *"Which boss drops that item?"* — have all the info right on your screen.

## ✨ Key Features

*   **Automatic Detection:** The checklist appears automatically when you enter a supported dungeon/raid and hides when you leave.
*   **Live Tracking:** Bosses are automatically marked as "Dead" (Checked) when killed.
*   **Dynamic Rare Detection:** Encountered a rare spawn not on the list? Just target them! If they are a known rare, the addon will magically add them to your checklist on the fly.
*   **Loot Browser:** Click the bag icon next to any boss to open a dedicated window showing their loot table with full interactive tooltips (Shift-Click to link, Ctrl-Click to try on).
*   **Quest Integration:** Bosses required for your active quests are highlighted in **Green** with a `[!]` icon.
*   **Compact Mode:** Minimize the window to a tiny progress bar (e.g., "Maraudon: 4/8 Bosses") to save screen space.
*   **Party Announce:** One-click button to announce remaining bosses to your party chat.
*   **Smart Icons:** Skull icons for bosses, Green Checks for kills, and distinct markers for Rare/Optional encounters.

## 🚀 Installation

1.  Download the latest release.
2.  Extract the `DungeonBossChecklist` folder into your WoW Addons directory:
    `_classic_era_\Interface\AddOns\`
3.  Launch the game!

## 📜 Chat Commands

| Command | Description |
| :--- | :--- |
| `/dbc` | Toggle the checklist window manually. |
| `/dbc show` | Force show the window. |
| `/dbc hide` | Force hide the window. |
| `/dbc reset` | Reset the current dungeon progress (uncheck all bosses). |
| `/dbc options` | Open the configuration panel. |
| `/dbc status` | Print current progress to chat window. |

## 🤝 Contributing

Contributions are welcome! If you find a bug or want to improve the data:

1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/NewBoss`).
3.  Commit your changes.
4.  Open a Pull Request.

### Updating Boss Data
The core data file `data.lua` contains the boss IDs, loot tables, and instance mapping.
*   **Missing Boss?** Add their `npcID` to the relevant section in `data.lua`.

## 📢 Credits & Data Source

This addon stands on the shoulders of giants. A massive thank you to:

*   **AtlasLootClassic Team:** For the comprehensive `data.lua` database structure and loot tables. [GitHub](https://github.com/Hoizame/AtlasLootClassic)
*   **RareScanner:** For the extensive database of rare mob IDs used for dynamic detection. [CurseForge](https://www.curseforge.com/wow/addons/rarescanner)

*   **License:** Please respect the original licenses of the data sources when redistributing.

---

*Made with ❤️ for WoW Classic.*