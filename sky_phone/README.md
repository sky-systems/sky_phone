# Sky Phone — Server installation

Sky Phone is a free, standalone FiveM phone for ESX, QBCore and Qbox.

> [!WARNING]
> **Use the prebuilt release ZIP for a server installation.**
> Under [Releases → Assets](https://github.com/sky-systems/sky_phone/releases/latest), choose **`sky_phone-<version>.zip`**.
> **Source code (zip / tar.gz)** and **Code → Download ZIP** contain developer sources without the built UI. The release package includes `fxmanifest.lua` and `source/html/index.html` inside one `sky_phone` folder.

Start with [INSTALL.md](INSTALL.md), then follow the detailed
[installation guide](PHONE_INSTALLATION_IMPORTANT.md) for your inventory,
permissions, start order and device/SIM setup. Copy inventory icons from
`config/images`; keep the resource folder named `sky_phone`.

For updates, read the current [RELEASE_NOTES.md](RELEASE_NOTES.md). Back up your
resource and database, retain your configuration and server peppers, and follow
the maintenance/restart instructions before reconnecting players.

## Guides

- [Full installation and compatibility](https://www.sky-systems.net/docs/scripts/free-phone/installation)
- [Inventory items and images](https://www.sky-systems.net/docs/scripts/free-phone/inventory-items)
- [Configuration and administrator access](https://www.sky-systems.net/docs/scripts/free-phone/configuration)
- [Discord logging](LOGGING.md)
- [Public APIs and custom apps](integrations/README.md)
- [Features and developer source](https://github.com/sky-systems/sky_phone)
- [Discord support](https://discord.gg/sky-systems)

KnoWay is optional and disabled by default. The `knowayest` vehicle is included;
select it or a verified custom model in the active configuration before enabling
the app. Follow the [KnoWay guide](https://github.com/sky-systems/sky_phone/blob/dev/docs/knoway.md).
The vehicle retains its [creator's attribution and free-distribution terms](https://github.com/sky-systems/sky_phone/blob/dev/THIRD_PARTY_ASSETS.md).

Sky Phone's software is licensed under [GPL-3.0](LICENSE). Frontend component
licenses are included in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
