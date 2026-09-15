# Sky Phone 18 Pro Max prop

Editable Blender 5.2 / Sollumz source, native GTA V Gen8 drawables and a proximity display integration for the standalone sky_phone resource.

## Files

- `sky_phone_prop.blend`: all 16 variants, GTA shader materials, four LODs, collision, archetypes and studio camera.
- `source/build_sky_phone_prop.py`: deterministic build using the installed Sollumz extension. Run with Blender in background mode.
- `source/xml`: editable CodeWalker XML exports.
- `source/textures`: embedded BGRA8 DDS textures with complete mip chains.
- `../../sky_phone/stream/phone_prop`: native YDR/YTYP files; already registered in the resource manifest.
- `previews`: renders made from the generated meshes. Studio PBR lighting is a preview, not an in-game screenshot.

## Design and colors

The chassis is 78.0 × 163.4 × 8.75 mm in meter-based GTA coordinates, with additional camera protrusion. Dimensions follow [Apple's specifications](https://www.apple.com/iphone-18-pro/specs/). Camera layout and rear panel follow the supplied front/back reference. The rear carries the GTA iFruit fruit-bowl logo as separate flush metal inlays, as requested. The logo reference is [Rockstar iFruit merchandise](https://store.rockstargames.com/merchandise/buy-ifruit-mouse-pad). Unseen side details, curvature, logo outline and optical construction are modeled approximations; this is not manufacturer CAD.

All 15 existing frame IDs are supported: black, blue, green, lavender, red, white, orange, yellow, lime, teal, cyan, purple, pink, gold, rgb. The builder reads the existing frontend palette. RGB uses a static multicolor anodized finish. An additional burgundy model reproduces the reference color and can be selected as a fixed custom prop.

## Installation and existing servers

Deploy the built `sky_phone` resource and restart it. Fresh defaults use `Animations.PropModel = "sky_phone_prop"`. Existing SQL Phone Configurator settings that still select the previous shipped `prop_npc_phone_02` default are upgraded once to `sky_phone_prop` on resource startup. The migration persists the choice, advances the configuration revision and synchronizes clients, while preserving custom models, hand transforms and unrelated settings. Later explicit administrator choices remain authoritative. For file-based configuration, set `Config.Animations.PropModel` in `config/config.lua` to `sky_phone_prop`. Other custom prop models remain supported and keep their original behavior. Frame color changes replace the networked prop using the existing attachment/animation lifecycle.

The separate black OLED mesh has UVs from 0 to 1. Front is -Y, top is +Z, origin is at chassis center. Display dimensions and local offset are shared in `source/shared/phone_prop.lua`. The existing portrait/landscape attachment transforms are reused and must be checked on the server's ped models/animations.

## Nearby screen behavior

Each player has an independent DUI texture, drawn on the rounded screen with depth and facing checks. The overlay sits at local Y=-0.0055, 0.79 mm in front of the outer glass/camera geometry. The renderer refreshes the hand attachments and reads one current prop matrix per frame, keeping all polygon vertices in the same pose during movement. A temporary off-screen/back-facing frame does not put an active display into the idle polling interval. No global texture replacement is used. Only the main phone screen is captured; neither the desktop nor the game framebuffer is captured.

- 360 × 780 JPEG, up to 2 updates per second, at most 64 KB per image.
- Server-checked device possession, prop ownership/model and proximity within 3 meters.
- Same routing bucket only; all qualifying nearby spectators receive frames.
- At most 12 simultaneous DUI instances per client. Allocation is first available; additional displays stay black until capacity frees up.
- Closed, deleted, departed, restricted or stale devices stop streaming; browsers and local display instances are released.
- No audio, account store or raw HTML is sent to observers. Pixels can contain anything visibly displayed on the player's in-game phone.
- JPEG type, size and dimensions are checked before display. Spectator HTML permits only bundled script/style and data images.

The capture is a low-rate visual mirror, not a 60 FPS video stream. Cross-origin iframes are omitted; remote media without canvas/CORS permission may appear blank or cause that capture to fail. Camera and video behavior must be checked with the actual FiveM CEF runtime. The plain spectator page has no NUI callbacks or phone account context.

## Validation

See `source/build_report.json` and `source/validation_report.json` for native asset checks. The branch includes server proximity/session regression tests and browser capture/spectator tests. Local build/browser checks are distinct from live FiveM testing.

Live acceptance requires two or more clients: different screens/colors simultaneously; approach/leave 3 m; close/reopen; switch characters; routing-bucket change; prop deletion; call/camera/landscape modes; resource restart. Inspect screen alignment, readable orientation, geometry depth and attachment on the intended ped models.
