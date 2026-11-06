# Downloaded the source code?

This repository is the developer source. GitHub's **Code → Download ZIP** and
automatic **Source code (zip / tar.gz)** downloads do not include the compiled
phone UI. Copying them into a FiveM server does not install a working phone.

For a server installation:

1. Open the [latest release](https://github.com/sky-systems/sky_phone/releases/latest).
2. Under **Assets**, download **`sky_phone-<version>.zip`**. Do not choose either
   **Source code** download.
3. Extract the ZIP. Copy the included `sky_phone` folder into your server's
   `resources` directory; `fxmanifest.lua` and `source/html/index.html` must be
   inside that folder.
4. Follow the included **INSTALL.md** and **PHONE_INSTALLATION_IMPORTANT.md**.

Developers can build this source with the steps in
[Frontend development](README.md#frontend-development). A normal release
installation needs neither Node.js nor pnpm.
