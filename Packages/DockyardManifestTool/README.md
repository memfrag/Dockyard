# DockyardManifestTool

Build a Dockyard catalog manifest from a config file by resolving each app's latest GitHub release.

Run it locally whenever you cut a release. It reads a small JSON config listing your apps and their GitHub repos, queries the public GitHub API for each app's latest release, picks the correct DMG asset, and writes a `manifest.json` that the Dockyard app consumes at runtime.

## 1. Create a config file

Save as `dockyard.config.json` anywhere you like:

```json
{
  "apps": [
    {
      "id": "com.apparata.widget",
      "displayName": "Widget",
      "category": "Productivity",
      "summary": "Short card description.",
      "iconURL": "https://your.cdn/dockyard/icons/widget-v1.png",
      "github": { "owner": "apparata", "repo": "widget-mac" },
      "assetPattern": "^Widget-.*\\.dmg$",
      "channel": "Beta"
    }
  ]
}
```

- `id` **must** equal the built `.app`'s `CFBundleIdentifier`. The Dockyard engine validates this at install time.
- `assetPattern` is optional; omit it and the tool picks the first `*.dmg` in the release.
- `iconURL` must already be hosted somewhere — the tool does **not** upload the icon, it just copies the URL into the manifest. Use a versioned path (e.g. `widget-v2.png`) when you change the bitmap; the engine caches icons purely by URL and does not revalidate.
- `channel` is optional; values are `"Beta"` or `"Release"`. Omit for release apps — the builder defaults to `Release`.

## 2. (Optional) store a GitHub token

Unauthenticated, the GitHub API allows 60 requests per hour per IP. A classic Personal Access Token with no scopes lifts that to 5000/hr for public releases.

```
cd Packages/DockyardManifestTool
swift run dockyard-manifest-tool set-token
# paste the token at the prompt (input is hidden), press return
```

Verify if you like:

```
security find-generic-password -s io.apparata.dockyard-manifest-tool
```

Remove it later with:

```
swift run dockyard-manifest-tool clear-token
```

The token is stored in your login Keychain under service `io.apparata.dockyard-manifest-tool`, account `github-token`. If no token is present the tool runs unauthenticated.

## 3. Build the manifest

```
swift run dockyard-manifest-tool build \
  --config ~/path/to/dockyard.config.json \
  --output ~/path/to/manifest.json
```

Add `--hash` to download each DMG and embed a `dmgSHA256` — useful on release day when you want the engine to verify integrity; slow because it downloads every DMG:

```
swift run dockyard-manifest-tool build \
  --config ~/path/to/dockyard.config.json \
  --output ~/path/to/manifest.json \
  --hash
```

On success you'll see `Wrote .../manifest.json (N apps)`. If nothing except the `generatedAt` timestamp would change, the tool prints `No changes; ... is up to date` and skips the write — so `git diff` on the manifest stays clean across back-to-back runs with the same release state.

## 4. Host `manifest.json`

Put the generated file at any static URL — GitHub Pages, S3, Cloudflare Pages, your own server. Then open `Dockyard/macOS/App Environment/AppEnvironment+Live.swift` (and `+Mock.swift` if you use the mock environment) and replace the placeholder `https://example.com/dockyard/manifest.json` with your real URL.

## Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Success |
| `1`  | Config file or IO error |
| `2`  | GitHub API error (includes rate-limit; the message shows when the limit resets) |
| `3`  | No DMG asset matched the pattern (or no `*.dmg` at all) |
| `4`  | Network / transport error |
| `5`  | Keychain error |

The tool is fail-fast: if any one app in the config fails to resolve, the run aborts and **no** manifest is written. Fix the offending entry and re-run.

## Getting help

```
swift run dockyard-manifest-tool --help
swift run dockyard-manifest-tool build --help
swift run dockyard-manifest-tool set-token --help
swift run dockyard-manifest-tool clear-token --help
```
