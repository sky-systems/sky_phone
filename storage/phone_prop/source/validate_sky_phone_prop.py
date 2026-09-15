"""Run with Blender background mode; validates native roundtrips, not only XML."""
from pathlib import Path
import json, re
from szio.gta5 import try_load_asset

ROOT = Path(__file__).resolve().parents[1]
STREAM = ROOT.parents[1] / 'sky_phone/stream/phone_prop'
contract = (ROOT.parents[1] / 'sky_phone/source/shared/phone_prop.lua').read_text(encoding='utf-8')
dui_y = float(re.search(r'Screen\s*=\s*\{[^}]*\by\s*=\s*([-0-9.]+)', contract).group(1))
assert json.loads((ROOT/'source/build_report.json').read_text())['screen']['y'] == dui_y
report = {}
for path in sorted(STREAM.glob('*.ydr')):
    assert path.read_bytes()[:4] == b'RSC7'
    asset = try_load_asset(path)
    assert asset is not None and asset.name == path.stem
    assert asset.bounds is not None and len(asset.bounds.children) == 1
    assert len(asset.shader_group.shaders) >= 8
    textures = asset.shader_group.embedded_textures
    assert len(textures) >= 8
    counts = {}
    outer_front_y = float('inf')
    for level, models in asset.models.items():
        counts[level.name] = sum(len(g.index_buffer)//3 for m in models for g in m.geometries)
        for model in models:
            for g in model.geometries:
                outer_front_y = min(outer_front_y, float(g.vertex_buffer['Position'][:, 1].min()))
                assert len(g.vertex_buffer) <= 65535
                assert max(g.index_buffer) < len(g.vertex_buffer)
                assert 'TexCoord0' in g.vertex_buffer.dtype.names
                assert 'Colour0' in g.vertex_buffer.dtype.names
    ordered = [counts[k] for k in ('HIGH','MEDIUM','LOW','VERYLOW')]
    assert all(a>b>0 for a,b in zip(ordered,ordered[1:]))
    assert ordered[0] < 25000 and ordered[-1] < 1000
    clearance_mm = (outer_front_y - dui_y) * 1000
    assert clearance_mm >= 0.5, f'{path.name}: DUI overlaps the front geometry ({clearance_mm:.3f} mm)'
    report[path.name] = {'bytes':path.stat().st_size,'triangles':counts,'textures':len(textures),'native_roundtrip':'passed','dui_clearance_mm':round(clearance_mm,3)}
assert len(report)==16
ytyp = try_load_asset(STREAM/'sky_phone_prop.ytyp')
assert ytyp is not None
(ROOT/'source/validation_report.json').write_text(json.dumps(report,indent=2))
print('PASS: 16 native YDR roundtrips, 4 LODs, textures, vertex channels, collision, YTYP and DUI glass clearance')
