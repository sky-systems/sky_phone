# Repository rulesets

These JSON files are import-ready repository rulesets for `sky-systems/sky_phone`.

## Activation order

1. Merge the governance files and workflows into the default `dev` branch.
2. Let `CI`, `Automated code review`, and `Pull request policy` run once so GitHub registers the check names.
3. Open **Settings > Rules > Rulesets > New ruleset > Import a ruleset**.
4. Import `protect-dev.json`, review its target and required checks, then activate it.
5. Import `protect-release-tags.json`, review the numeric tag pattern, then activate it.
6. Open a test pull request and confirm all five required checks and the test-resource comment are reported before relying on the ruleset.

`protect-dev.json` blocks deletion and force pushes, restricts all updates of `dev` to the built-in `Maintain` role, requires one approval, dismisses stale reviews, requires approval after the last push, resolves review conversations, and requires the `Repository policy`, `Frontend`, `CodeQL`, `Dependency review`, and `Pull request policy` checks. Maintainers can bypass rules only through a pull request, so they cannot use this bypass for a direct push to `dev`.

Successful pull requests receive a 14-day test-resource artifact containing the deployable `sky_phone` folder and built NUI. `Pull request test resource link` runs after `CI` and maintains one download comment in the pull request. It does not check out, download, or execute pull-request content with its write-capable token.

`protect-release-tags.json` accepts stable numeric semantic versions such as `0.2.0`, rejects a leading `v`, and makes created tags immutable.

The built-in repository `Maintain` role uses `RepositoryRole` actor ID `2`. Its branch bypass is limited to pull requests and is what permits maintainers to merge; its tag bypass is always available so maintainers can create and recover releases. Changing the committed JSON alone does not update an already imported ruleset.

Rulesets are GitHub settings, not live configuration files. Committing or editing these JSON files does not activate or update protection automatically; an administrator must import or reconcile them in GitHub.
