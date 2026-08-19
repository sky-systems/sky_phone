# Repository rulesets

These JSON files are import-ready repository rulesets for `sky-systems/sky_phone`.

## Activation order

1. Merge the governance files and workflows into the default `dev` branch.
2. Let `CI` and `Pull request policy` run once so GitHub registers the check names.
3. Open **Settings > Rules > Rulesets > New ruleset > Import a ruleset**.
4. Import `protect-dev.json`, review its target and required checks, then activate it.
5. Import `protect-release-tags.json`, review the numeric tag pattern, then activate it.
6. Open a test pull request and confirm all three required checks are reported before relying on the ruleset.

`protect-dev.json` blocks deletion and force pushes, requires one approval, dismisses stale reviews, requires approval after the last push, resolves review conversations, and requires the `Repository policy`, `Frontend`, and `Pull request policy` checks.

`protect-release-tags.json` accepts stable numeric semantic versions such as `0.2.0`, rejects a leading `v`, and makes created tags immutable.

The built-in repository `Maintain` role (`RepositoryRole` actor ID `2`) has an explicit emergency bypass in both files. Use it only for audited recovery work. Remove the bypass in GitHub if maintainers should remain subject to every rule; changing the committed JSON alone does not update an already imported ruleset.

Rulesets are GitHub settings, not live configuration files. Committing or editing these JSON files does not activate or update protection automatically; an administrator must import or reconcile them in GitHub.
