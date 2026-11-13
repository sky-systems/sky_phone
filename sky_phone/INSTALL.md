# Sky Free Phone — Installation

Use the published **release package** with its built UI. GitHub's automatic Source code ZIP is not the installed package. Copy the complete `sky_phone` folder into `resources/`; keep its name. Stop another phone resource handling the same item.

Required: oxmysql, ESX/QBCore/Qbox, a supported inventory and YACA/PMA Voice/SaltyChat. This Phone has its own adapters; Base and Jobs Base are not dependencies.

1. Register the phone item and, when physical SIM mode is enabled, `sky_phone_sim_registered` and `sky_phone_sim_anonymous`. Use your inventory's exact definitions and copy `config/images` icons. Unique devices/SIMs require supported metadata handling. **The ox use exports belong only in ox_inventory.**
2. Put both lines before Phone starts in `server.cfg`:

```cfg
add_ace resource.sky_phone command.add_ace allow
add_ace resource.sky_phone command.remove_ace allow
```

3. Start oxmysql, framework, inventory and selected voice provider, then `ensure sky_phone`. Verify administrator ACE membership matches `Config.CommandPermissions`; Base's ACE setup does not grant Phone access.
4. With `Config.PhoneConfigurator.Enabled = true`, use `/phonepanel > Phone configurator`. Check framework, inventory, language, phone/SIM/unique-device mode and voice, then save with the checkmark. Managed Part 2/media file values are ignored in SQL mode. Part 1 remains file-owned.
5. Fully restart after startup permission/provider changes and reconnect. Migrations normally run automatically; a manual SQL import is not required. Test item use, SIM/device identity, a two-player call/message and persistence.

Back up SQL/configuration and persistent files before updating. Merge settings and retain devices/accounts. Complete provider compatibility checks before enabling unique devices or physical SIMs.

For optional physical cell towers, copy `config/images/radiotowerparts.png` to your inventory's image directory when registering the repair item. Use the existing inventory icon for `lockpick`. [Physical tower item setup](https://www.sky-systems.net/docs/scripts/free-phone/inventory-items#physical-tower-items)

- [Full installation and compatibility](https://www.sky-systems.net/docs/scripts/free-phone/installation)
- [Provider-specific inventory definitions](https://www.sky-systems.net/docs/scripts/free-phone/inventory-items)
- [Configuration and admin access](https://www.sky-systems.net/docs/scripts/free-phone/configuration)
- [Support](https://discord.gg/sky-systems)
