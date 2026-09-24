# App theme regression tests

Run from `frontend` with Node 22 and pnpm 10:

```sh
pnpm install --frozen-lockfile
pnpm exec playwright install chromium
pnpm test:themes
```

On Windows an installed Edge can be used with `$env:PLAYWRIGHT_CHANNEL = 'msedge'`.
The suite starts isolated Vite and fixture API servers on 5198 / 3098; it does not use your game server or Cloudflare credentials. CI installs Chromium and runs this command in the existing **Frontend** check.

## Automatic coverage

The browser reads `PHONE_APPS` from the running app. Every registered built-in app is opened in both appearance modes and switched to the opposite mode while mounted. Adding an app to the catalog automatically includes it; there is no second list to maintain. External resource iframes require their own fixtures and are not part of this repository's app catalog test.

The assertions check the effective Sky palette and color scheme, opaque page backgrounds, visible text, icon-only controls, field values, placeholders, and the phone status bar. A 3:1 contrast floor catches severe color regressions, including white on white and black on black. It is not a full WCAG AA audit, which requires 4.5:1 for normal text. A deliberately broken fixture verifies that the guard actually fails for wrong page surfaces and unreadable text, icons and input values. It also verifies that decorative button backgrounds are included in the contrast measurement.

Background alpha is composited. Simple gradients are checked against their color bounds. Images, video, transparent game backgrounds and gradients with ambiguous bounds are recorded as **skipped**, not counted as passing contrast checks. Each app still receives a palette check and a screenshot. Camera and Weather explicitly declare `data-theme-policy="scene"` because their immersive scene controls use a dark Sky palette in either phone mode; this does not skip their text checks.

Account scenarios additionally cover login and registration (empty, filled and rejected submission) in Feather, CrewLink, CityMarkt, Local Pages, Picstagram, FlipTok, VaultX, Mail and Sky Cloud. Flare onboarding, Feather's first profile setup and Calendar's account-required view are checked too. A source discovery guard requires a fixture for new standard account-entry views, including apps using `AppProfileAuth` or an `authMode` / `accountMode` state. Authentication submissions are intercepted inside the browser so these checks cannot create accounts.

Additional browser scenarios cover Feather's profile and editor, both social discovery views, live avatar entry, empty and filled live forms, host/viewer counters and chat, host-composer geometry above the real app navigation/home indicator, direct video/audio answering, and audio-button state/color with integrated PMA and SaltyChat controls. These use the production Vue components with development media fixtures, not a real FiveM/voice-provider connection.

The FaceTime regression in `realtime.pw.mjs` additionally connects two native browser WebRTC peers with canvas video tracks. It deliberately delivers the offer before the receiving peer roster and requires decoded video in both directions. Only signaling is simulated; gameplay capture, arm animation and camera framing still require an in-game test.

## Review and extend

Reports and screenshots are written to `theme-test-results` and `playwright-report` (gitignored). Open the report with `pnpm exec playwright show-report`. CI attaches the reports when the Frontend job fails. Review skipped image/gradient areas in the screenshots. Fix colors with semantic Sky tokens; do not add an app-wide exclusion to hide a failure.

The catalog test covers each app's initial visible screen, not every possible navigation state. Add representative forms, dialogs and deeper screens to `auth.pw.mjs`, `social.pw.mjs` or another `*.pw.mjs` scenario when introducing such flows. Keep fixture actions local and avoid external accounts or real media services.
