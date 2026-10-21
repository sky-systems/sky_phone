"""Render the delivered native drawables, independently of the authoring blend."""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build

for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
names = ("tower", "door", "panel", "panel_broken")
assert bpy.ops.sollumz.import_assets(
    directory=str(build.STREAM),
    files=[{"name": build.PREFIX + name + ".ydr"} for name in names],
    use_custom_settings=True, textures_mode="PACK",
) == {"FINISHED"}
roots = {name: bpy.data.objects[build.PREFIX + name] for name in names}
if "--" in sys.argv:
    build.render_preview(roots, states=sys.argv[sys.argv.index("--") + 1:])
else:
    build.render_preview(roots)
print("CELL_TOWERS_NATIVE_PREVIEWS_OK", flush=True)
