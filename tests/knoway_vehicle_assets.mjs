import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const resource = path.join(root, "sky_phone");
const originalContainers = new Map([
  [
    "knowayest.yft",
    "95b1409565f758149ea94974a2991f0e18b2fb7cf3134b7179a323a10e01d315",
  ],
  [
    "knowayest_hi.yft",
    "a75982de24bdb927219cb3c734f3b8d1aabecfde58b2258c5fdf6f17e46f2ad4",
  ],
  [
    "knowayest.ytd",
    "0545eddd545713c69076f84177833f81eec186da446f85a1cb054c45b24a07e5",
  ],
  [
    "knowayest+hi.ytd",
    "c08e6328033f4da3cef5c98dbc8938902091029cbe76db006ccbbfff61a0919f",
  ],
]);

for (const [name, digest] of originalContainers) {
  const contents = await readFile(path.join(resource, "stream", name));
  assert.equal(
    contents.toString("ascii", 0, 4),
    "RSC7",
    `${name} must remain an RSC7 game asset`,
  );
  assert.equal(
    createHash("sha256").update(contents).digest("hex"),
    digest,
    `${name} must retain the reviewed original model or texture container`,
  );
}

async function checkStream(directory, prefix = "") {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const relative = path.posix.join(prefix, entry.name);
    if (entry.isDirectory()) {
      assert.ok(
        !/^(?:backups?|.*_old)$/i.test(entry.name),
        "Do not package historical asset folders",
      );
      await checkStream(path.join(directory, entry.name), relative);
    } else if (originalContainers.has(entry.name)) {
      assert.equal(
        relative,
        entry.name,
        `${entry.name} must be streamed once from the flat stream directory`,
      );
    }
  }
}
await checkStream(path.join(resource, "stream"));

const definitions = [
  ["vehiclelayouts.meta", "CVehicleMetadataMgr", "VEHICLE_LAYOUTS_FILE"],
  ["handling.meta", "CHandlingDataMgr", "HANDLING_FILE"],
  ["vehicles.meta", "CVehicleModelInfo__InitDataList", "VEHICLE_METADATA_FILE"],
  [
    "carvariations.meta",
    "CVehicleModelInfoVariation",
    "VEHICLE_VARIATION_FILE",
  ],
];
const xml = new Map();
const manifest = await readFile(path.join(resource, "fxmanifest.lua"), "utf8");
assert.match(manifest, /\bfiles\s*\{([\s\S]*?)\}/);
const fileSection = /\bfiles\s*\{([\s\S]*?)\}/.exec(manifest)[1];
const listed = [...fileSection.matchAll(/["']([^"']+)["']/g)].map(
  (match) => match[1],
);
const mounts = [
  ...manifest.matchAll(/^\s*data_file\s+["']([^"']+)["']\s+["']([^"']+)["']/gm),
];
for (const [name, rootTag, mountType] of definitions) {
  const text = (
    await readFile(path.join(resource, "data", name), "utf8")
  ).replace(/\r\n?/g, "\n");
  assert.ok(
    text.includes(`<${rootTag}>`) && text.trimEnd().endsWith(`</${rootTag}>`),
    `${name} must retain the expected GTA metadata root`,
  );
  xml.set(name, text);
  const relative = `data/${name}`;
  assert.equal(
    listed.filter((file) => file === relative).length,
    1,
    `${relative} must be published once`,
  );
  const registrations = mounts.filter((match) => match[2] === relative);
  assert.equal(
    registrations.length,
    1,
    `${relative} must have one explicit metadata mount`,
  );
  assert.equal(
    registrations[0][1],
    mountType,
    `${relative} must use the matching GTA data-file type`,
  );
}
assert.ok(
  mounts.findIndex((mount) => mount[2] === "data/vehiclelayouts.meta") <
    mounts.findIndex((mount) => mount[2] === "data/vehicles.meta"),
  "The isolated seat layouts must load before the vehicle that references them",
);

const vehicles = xml.get("vehicles.meta");
for (const [tag, value] of [
  ["modelName", "knowayest"],
  ["txdName", "knowayest"],
  ["handlingId", "KNOWAYEST"],
  ["gameName", "KNOWAYEST"],
  ["audioNameHash", "NEON"],
]) {
  const values = [
    ...vehicles.matchAll(new RegExp(`<${tag}>([^<]+)</${tag}>`, "g")),
  ];
  assert.deepEqual(
    values.map((match) => match[1]),
    [value],
    `Unexpected KnoWay ${tag}`,
  );
}
assert.match(
  xml.get("handling.meta"),
  /<handlingName>KNOWAYEST<\/handlingName>/,
);
assert.match(
  xml.get("carvariations.meta"),
  /<modelName>knowayest<\/modelName>/,
);
const layouts = xml.get("vehiclelayouts.meta");
const names = [...layouts.matchAll(/<Name>([^<]+)<\/Name>/g)].map(
  (match) => match[1],
);
assert.equal(
  names.length,
  10,
  "Retain the ten reviewed compatibility definitions",
);
assert.equal(
  new Set(names).size,
  names.length,
  "Layout definition names must remain unique",
);
assert.ok(
  names.every((name) => name.startsWith("KNOWAYEST_")),
  "Bundled compatibility layouts must not replace shared GTA vehicle definitions",
);
const localReferences = [...layouts.matchAll(/\bref="(KNOWAYEST_[^"]+)"/g)].map(
  (match) => match[1],
);
for (const tag of ["layout", "coverBoundOffsets"]) {
  const reference = new RegExp(`<${tag}>([^<]+)</${tag}>`).exec(vehicles);
  assert.ok(reference, `Missing vehicle ${tag} reference`);
  localReferences.push(reference[1]);
}
for (const reference of localReferences) {
  assert.ok(
    names.includes(reference),
    `Missing bundled compatibility definition: ${reference}`,
  );
}

const notice = await readFile(path.join(root, "THIRD_PARTY_ASSETS.md"), "utf8");
for (const credit of [
  "Rockstar Games",
  "Roost4R",
  "sirstirfry",
  "Suzuka",
  "a_asdf556",
  "JsH",
  "HexR",
]) {
  assert.ok(
    notice.includes(credit),
    `The repository asset notice must retain ${credit}'s credit`,
  );
}
assert.ok(
  notice.includes("https://www.gta5-mods.com/vehicles/knoway-ocelot-e-stride"),
);
assert.match(
  notice,
  /paywall/i,
  "The separate asset notice must retain the creator distribution restriction",
);
assert.match(
  notice,
  /GPL/i,
  "Explain that vehicle content is separate from the phone software license",
);
for (const directory of [resource, path.join(root, "frontend")]) {
  const entries = await readdir(directory);
  assert.ok(
    !entries.includes("THIRD_PARTY_ASSETS.md"),
    "Keep vehicle attribution outside the resource and frontend",
  );
}
assert.ok(
  !manifest.includes("THIRD_PARTY_ASSETS"),
  "Repository attribution must not be delivered as a client file",
);

console.log(
  "PASS KnoWay vehicle assets: original RSC7 hashes, flat streaming, metadata mounts and isolated layout graph, repository-only attribution",
);
