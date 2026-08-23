import { readFile, readdir } from "node:fs/promises";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, "..", "..");
const failures = [];

function fail(message) {
  failures.push(message);
}

const manifestPath = join(repositoryRoot, "sky_phone", "fxmanifest.lua");
const manifest = await readFile(manifestPath, "utf8");

for (const requiredFragment of [
  "fx_version 'cerulean'",
  "node_version '22'",
  "use_experimental_fxv2_oal 'yes'",
  "'source/server/nui_build_check.lua'",
  "'source/html/sounds/**'",
  "ui_page 'source/html/index.html'",
]) {
  if (!manifest.includes(requiredFragment)) {
    fail(`fxmanifest.lua is missing required contract: ${requiredFragment}`);
  }
}

const rulesetDirectory = join(repositoryRoot, ".github", "rulesets");
const rulesetFiles = (await readdir(rulesetDirectory)).filter((file) =>
  file.endsWith(".json"),
);
const requiredContexts = new Set([
  "Repository policy",
  "Frontend",
  "CodeQL",
  "Dependency review",
  "Pull request policy",
]);

for (const file of rulesetFiles) {
  const path = join(rulesetDirectory, file);
  let ruleset;

  try {
    ruleset = JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    fail(`${file} is not valid JSON: ${error.message}`);
    continue;
  }

  if (!ruleset.name || !["branch", "tag"].includes(ruleset.target)) {
    fail(`${file} must define a name and a branch or tag target`);
  }

  if (!Array.isArray(ruleset.rules) || ruleset.rules.length === 0) {
    fail(`${file} must contain at least one rule`);
  }

  const expectedBypassMode =
    ruleset.target === "branch" ? "pull_request" : "always";
  const maintainBypass = ruleset.bypass_actors?.some(
    (actor) =>
      actor.actor_type === "RepositoryRole" &&
      actor.actor_id === 2 &&
      actor.bypass_mode === expectedBypassMode,
  );
  if (!maintainBypass) {
    fail(`${file} must retain the expected Maintain role bypass`);
  }

  if (
    ruleset.target === "branch" &&
    !ruleset.rules?.some((rule) => rule.type === "update")
  ) {
    fail(`${file} must restrict default-branch updates to bypass actors`);
  }

  const statusRule = ruleset.rules?.find(
    (rule) => rule.type === "required_status_checks",
  );
  if (statusRule) {
    const contexts = new Set(
      statusRule.parameters?.required_status_checks?.map(
        (check) => check.context,
      ) ?? [],
    );
    for (const context of requiredContexts) {
      if (!contexts.has(context)) {
        fail(`${file} is missing required status context: ${context}`);
      }
    }
  }
}

const sourceRoots = [
  join(repositoryRoot, "sky_phone"),
  join(repositoryRoot, "frontend", "src"),
];
const inspectedExtensions = new Set([
  ".cjs",
  ".js",
  ".json",
  ".lua",
  ".mjs",
  ".sql",
  ".ts",
  ".vue",
]);
const forbiddenPatterns = [
  {
    label: "a forbidden Sky resource reference",
    pattern: /\bsky_(?:base|jobs_base)(?::|\b)/i,
  },
  {
    label: "a forbidden shared Sky global",
    pattern: /\bSky\.(?:FW|Cb|DB|Query)\b/,
  },
];

async function inspectDirectory(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (
      entry.name === "html" &&
      directory.endsWith(join("sky_phone", "source"))
    ) {
      continue;
    }

    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      await inspectDirectory(path);
      continue;
    }

    if (!inspectedExtensions.has(extname(entry.name))) {
      continue;
    }

    const content = await readFile(path, "utf8");
    for (const { label, pattern } of forbiddenPatterns) {
      if (pattern.test(content)) {
        fail(`${path.slice(repositoryRoot.length + 1)} contains ${label}`);
      }
    }
  }
}

for (const sourceRoot of sourceRoots) {
  await inspectDirectory(sourceRoot);
}

if (failures.length > 0) {
  console.error("Repository policy validation failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(
  `Repository policy validation passed (${rulesetFiles.length} rulesets checked).`,
);
