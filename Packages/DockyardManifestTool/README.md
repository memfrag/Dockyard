# DockyardManifestTool

Build and publish a Dockyard catalog manifest from a config file by resolving each app's latest GitHub release.

The tool reads a small JSON config listing app repos, queries the GitHub API for each app's latest release, picks the correct DMG asset, merges in metadata the app repo publishes about itself (`.dockyard/dockyard.json`), and writes a `manifest.json` that the Dockyard app consumes at runtime. It can also commit and push that manifest in one step (`publish`), and scaffold everything needed to onboard a new app (`add`).

## Quick reference

| Task | Command |
|------|---------|
| Add a new app to the catalog | `./add-app.sh` (or `swift run dockyard-manifest-tool add owner/repo --config .../dockyard.config.json`) |
| Publish new releases (local) | `./publish.sh` (or `swift run dockyard-manifest-tool publish --manifest-repo ...`) |
| Publish new releases (CI) | Nothing — the DockyardManifest repo's scheduled workflow picks them up daily |
| Build without committing | `./update-manifest.sh` (or the `build` subcommand) |

## 1. The config file

`dockyard.config.json` in the DockyardManifest repo. Only `github` is required per entry — everything else can live in the app repo itself (see next section):

```json
{
  "apps": [
    { "github": { "owner": "apparata", "repo": "widget-mac" } }
  ]
}
```

Any field you set here **overrides** what the app repo publishes, so the catalog curator always has the last word:

```json
{
  "apps": [
    {
      "github": { "owner": "apparata", "repo": "widget-mac" },
      "id": "com.apparata.widget",
      "displayName": "Widget",
      "category": "Productivity",
      "summary": "Short card description.",
      "iconURL": "https://your.cdn/dockyard/icons/widget-v1.png",
      "assetPattern": "^Widget-.*\\.dmg$",
      "channel": "Beta"
    }
  ]
}
```

### Web apps

An entry that opens in the browser instead of installing goes in a separate `webApps` array. It has no GitHub repo, no release and no `.dockyard/` folder, so everything is stated inline:

```json
{
  "apps": [ ... ],
  "webApps": [
    {
      "id": "web.example.app",
      "displayName": "Example Web App",
      "category": "Productivity",
      "summary": "A web app that opens in your browser.",
      "iconURL": "https://your.cdn/dockyard/icons/example.png",
      "webURL": "https://example.com/app",
      "developer": "Example AB",
      "channel": "Beta"
    }
  ]
}
```

- `id`, `displayName`, `category`, `summary`, `iconURL` and `webURL` are required; `channel`, `developer`, `aboutURL` and `screenshotURLs` are optional. `"TODO"` and blank values are rejected, as for native apps.
- `webURL` must be `http` or `https` — anything else is refused, since the app would otherwise silently do nothing when clicked.
- Ids must be unique across `apps` and `webApps`; the id is the join key for installed state, so a collision would make the UI confuse the two.
- Web apps are built entirely from this config: no GitHub API calls, no release lookup, no DMG hashing.
- **They stay in `webApps` for backward compatibility.** Dockyard 1.2.5 and earlier require `dmgURL`, `dmgSize` and `version` on every entry of `apps`, and one entry failing to decode fails the whole manifest — so a web app in `apps` would blank the catalog on every copy already installed. Those versions ignore the unknown `webApps` key and carry on. For the same reason `schemaVersion` must stay `1`: shipped clients gate on exact equality. Web apps need Dockyard 1.3.0 or later to be visible.
- Don't feature a web app in `editorial.json` until the install base has moved: older clients resolve editorial ids against their catalog, and a missing id makes that Today section disappear for them.

### Field notes

- `id` **must** equal the built `.app`'s `CFBundleIdentifier` for native apps. The Dockyard engine validates this at install time. For web apps nothing is installed, so it's just a stable catalog key — use a reserved-looking prefix such as `web.`.
- `assetPattern` is optional; omit it and the tool picks the first `*.dmg` in the release.
- `iconURL` is optional; omitted, the tool uses the app repo's `.dockyard/AppIcon.png`.
- `channel` is optional; values are `"Beta"` or `"Release"`. Defaults to `Release`.

## 2. Self-describing app repos (`.dockyard/`)

Each app repo can carry its own catalog metadata in a `.dockyard/` folder at the repo root:

```
.dockyard/
  dockyard.json            → app metadata (id, name, category, summary, ...)
  AppIcon.png              → the catalog icon (used when the config has no iconURL)
  about.md                 → rendered as the "About" section
  screenshots/
    01.png                 → rendered as the "Screenshots" section
    02.png                   (sorted alphabetically; png/jpg/jpeg/gif/webp only)
```

`dockyard.json` format (all fields except `schemaVersion` and `id` optional):

```json
{
  "schemaVersion": 1,
  "id": "com.apparata.widget",
  "displayName": "Widget",
  "category": "Productivity",
  "summary": "Short card description.",
  "assetPattern": "^Widget-.*\\.dmg$",
  "channel": "Release"
}
```

- After merging config + repo metadata, `id`, `displayName`, `category`, `summary`, and an icon must be present — otherwise the build fails with exit code 6 telling you which fields are missing. Literal `"TODO"` values (from a fresh scaffold) count as missing.
- `AppIcon.png` should be a square PNG with alpha, **512×512 pixels** (256×256 points @2x). `add` extracts one at that size from the app bundle for you.
- `about.md` and `screenshots/` are optional. If absent, the manifest simply omits those sections.
- Screenshot files should be **680×420 pixels** (340×210 points @2x) so they render crisp in the App Details view.
- Release notes for the "What's New" section come from the GitHub release description (`body`); cutting a new release automatically updates Dockyard on the next manifest build.

## 3. Adding a new app: `add`

```
./add-app.sh                      # asks for the repo, then does the rest
./add-app.sh apparata/widget-mac  # or name it up front
```

`add-app.sh` fills in the config path (override it with `DOCKYARD_CONFIG`), forwards any extra arguments to the command below, and offers to reveal the scaffold in Finder when it made one. The long form:

```
swift run dockyard-manifest-tool add apparata/widget-mac \
  --config ../../../DockyardManifest/dockyard.config.json
```

- If the repo already publishes a complete `.dockyard/` folder, the command just validates it and appends `{ "github": ... }` to the config.
- If anything is missing, it downloads the latest release DMG **once**, mounts it to read the app's `CFBundleIdentifier`, name and icon, and writes a ready-to-commit `.dockyard/` folder to a temp directory:

  ```
  Scaffolded into /var/folders/.../T/dockyard-scaffold/apparata-widget-mac:
    .dockyard/dockyard.json
    .dockyard/AppIcon.png
    .dockyard/about.md
    .dockyard/screenshots/README.md

  Next steps:
    1. Copy the scaffold into apparata/widget-mac:
         cp -R /var/folders/.../dockyard-scaffold/apparata-widget-mac/.dockyard <path-to-repo>/
    2. Fill in the TODO fields in .dockyard/dockyard.json and about.md
    3. Commit and push, then run build (or publish) to add the app to the catalog
  ```

- `AppIcon.png` is extracted from the app bundle at 512×512 — from its `.icns` when it has one, otherwise by rendering the icon the Finder shows (which covers icons that only exist inside a compiled `Assets.car`). If neither works, the command warns and leaves the file out.
- Only the missing pieces are scaffolded, so copying the folder into the repo can't clobber metadata the repo already publishes. `about.md` and `screenshots/` are seeded only on fresh onboarding (no `dockyard.json` at all).
- Existing files at the destination are never overwritten — they're reported as `left alone; already there`. Scaffolding straight into a checkout is therefore safe:

  ```
  ./add-app.sh memfrag/Flowplan --scaffold-out ../../../Flowplan
  ```

- Re-running `add` for a repo that's already in the config is fine: the config is left untouched and only the missing `.dockyard/` pieces are written. That's how you finish a half-done folder — e.g. a repo that has `AppIcon.png` and `about.md` but no `dockyard.json`.
- `--force-scaffold` regenerates every file and **overwrites** what's already there. Use it to refresh an icon after a redesign; don't point it at a repo whose `about.md` you care about.
- Note: rewriting the config normalizes its JSON formatting (pretty-printed, sorted keys) the first time.

## 4. Hashes (`dmgSHA256`)

Hashing is **on by default**. It no longer means downloading every DMG — the hash is resolved in three tiers, and the tier used is logged per app:

1. `digest` — GitHub's own SHA-256 for the asset, straight from the API. Free.
2. `cached` — the hash in the existing `manifest.json`, reused when the asset's URL **and** size are unchanged. Free.
3. `downloaded` — only for a genuinely new release whose asset has no API digest, the DMG is streamed once to compute the hash.

Flags: `--no-hash` skips hashing entirely (the Dockyard engine then installs without integrity verification — avoid), `--force-hash` ignores the cache tier and recomputes.

## 5. GitHub token

Precedence: `DOCKYARD_GITHUB_TOKEN` env var → `GITHUB_TOKEN` env var → Keychain. CI sets `GITHUB_TOKEN`; locally, store a token once in the Keychain:

```
cd Packages/DockyardManifestTool
swift run dockyard-manifest-tool set-token
# paste the token at the prompt (input is hidden), press return
```

Remove it later with `clear-token`. The token is stored in your login Keychain under service `io.apparata.dockyard-manifest-tool`, account `github-token`. Unauthenticated, the GitHub API allows 60 requests/hr; the tool makes roughly 7 API calls per app, so prefer a token (5000/hr) for catalogs with more than a few apps.

## 6. Building and publishing

Build only (writes `manifest.json`, never touches git):

```
./update-manifest.sh
# or
swift run dockyard-manifest-tool build --config .../dockyard.config.json --output .../manifest.json
```

If nothing except the `generatedAt` timestamp would change, the tool prints `No changes; ... is up to date` and skips the write — so `git diff` on the manifest stays clean across back-to-back runs.

Publish (build + diff summary + commit + push the DockyardManifest repo):

```
./publish.sh --dry-run    # preview the changes
./publish.sh              # commit + push with an auto-generated message
./publish.sh -m "..."     # custom commit message
```

`publish` refuses to run if unrelated changes are already staged in the manifest repo, so an in-progress config edit can't be swept into the manifest commit.

CI: the DockyardManifest repo has a scheduled workflow (`.github/workflows/update-manifest.yml`) that runs the build daily (and on manual dispatch) and pushes the manifest when it changed — routine app releases publish themselves with zero local steps. The workflow runs on a macOS runner (free for public repos), which is why the tool doesn't need a Linux port.

## Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Success |
| `1`  | Config file or IO error |
| `2`  | GitHub API error (includes rate-limit; the message shows when the limit resets) |
| `3`  | No DMG asset matched the pattern (or no `*.dmg` at all) |
| `4`  | Network / transport error |
| `5`  | Keychain error |
| `6`  | Missing or invalid app metadata after merging config + `.dockyard/dockyard.json` |
| `7`  | Git error during `publish` (or unrelated staged changes in the manifest repo) |

The tool is fail-fast: if any one app in the config fails to resolve, the run aborts and **no** manifest is written. Fix the offending entry and re-run.

## Getting help

```
swift run dockyard-manifest-tool --help
swift run dockyard-manifest-tool build --help
swift run dockyard-manifest-tool publish --help
swift run dockyard-manifest-tool add --help
```
