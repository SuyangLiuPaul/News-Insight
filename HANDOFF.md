# HANDOFF.md

Append-only log, newest on top, one entry per ship. This file is
canonical for **what happened**. `README.md` is allowed to drift; when
it disagrees with this file, this file wins — and when this file
disagrees with the tree, the tree wins.

---

## 2026-09-04 — handover documentation; nightly iOS failure diagnosed

No app behaviour changed.

Wrote the handover set the project did not have: `AGENTS.md` (entry
point), `CLAUDE.md` (pointer to it), `PROJECT_STATE.md`,
`docs/OPEN-ITEMS.md`, and this log. Structure follows the convention
already in use in the sibling SeekSparks repo, so someone moving between
the two finds the same files in the same roles.

Two things found while checking facts rather than repeating them:

- **The nightly iOS reinstall has been failing on both devices**, and
  the script was reporting the wrong reason. The real error is
  `kAMDMobileImageMounterDeviceLocked` — a developer disk image cannot
  mount on a locked device. At 04:40 the devices are locked, so this is
  the expected outcome every night, not a transient. Corrected the
  script's message to distinguish locked from unreachable, and re-synced
  the runtime copy at `~/.config/news-insight/scripts/`. What to *do*
  about it is an open decision for the owner — `docs/OPEN-ITEMS.md` #1.
- **The pipeline is now at 111/111 deep-matched, zero fallback**,
  measured off the live feed. On 2026-08-25 it was 72/132 with three
  desks near zero. Recorded in `PROJECT_STATE.md` along with a
  correction: the second API key recommended during that debugging was
  never added and was not needed.

Also verified and recorded: web and macOS are on 1.2.6; both iOS devices
and the published GitHub release are stranded on 1.2.4.

## 2026-08-25 — Creation and Documentary desks; theme aligned to the icon

**v1.2.5** added two desks, **v1.2.6** recoloured the app. Both deployed
to web; neither reached a phone.

**Desks.** `creation` (nature, environment, conservation) and
`documentary`. Creation takes Mongabay and Yale E360 plus the Guardian
environment and wildlife feeds, moved off the general science desk.
Documentary reuses the China desk's technique — broad culture feeds
(Guardian Film, Guardian TV & Radio, BBC Entertainment & Arts,
IndieWire) narrowed by a `documentary`/`docuseries` keyword filter —
because no dedicated documentary trade feed survives a bot-UA fetch;
RealScreen answers a challenge page. All feeds were fetched with the
pipeline's real User-Agent before being wired in, not assumed live. The
catalogue went from 22 feeds over 6 desks to 30 over 8.

App-side this needed almost nothing: chips are built from the feed's
`categoryLabel`, so the desks would have appeared without a release. The
section order list and the (unused) `ui_strings` entries were updated
for explicitness.

**Theme.** The icon, web splash and `theme_color` had been blue since
the icon redesign, but `AppTheme._seed` was still the pre-redesign amber
`0xFFB8860B`, with a comment asserting the clash was deliberate. Every
accent in the app fought the icon the user sees first. Changed the one
seed constant to the icon's `#2E72A4`; Material 3 derives the rest, and
there are no other hardcoded colours in `lib/`. Verified in light and
dark mode in a browser.

### The pipeline work that dominated this session

The owner's standing complaint was shallow verse matching. The cause was
not the prompt.

`gemini-2.5-flash`'s free tier is **~20 requests/day**, not the 1500 the
code comment claimed. Measured on a run fired three minutes after the
midnight-PDT reset, on an untouched budget: 15 successes, 92 429s,
degrading to zero. A 130-story edition was never coverable on it.

Four fixes, in the order they were found:

1. Default model → `gemini-2.5-flash-lite`.
2. **That first attempt did nothing**, because `refresh.yml` pinned
   `OPENAI_MODEL` in its `env:` block and silently overrode the script.
   Caught only by grepping which model the failures named — every one
   said `attempt 1/3 on gemini-2.5-flash`, i.e. the head of the ladder.
3. `OPENAI_MODEL_CHAIN` step-down: a 429 retries on the *next* model,
   since a per-day cap cannot be waited out with backoff. Chain ordered
   by evidence — `gemini-3-flash-preview` ahead of `gemini-2.5-flash`,
   because all 192 calls reaching the latter came back 429.
4. `rotateSectionOrder`: coverage had tracked processing position
   exactly (world 18/18 … creation 3/18), because budget was spent
   front-to-back. The offset advances per 4-hour window and is derived
   from absolute time — `hour % 8` under a 4-hourly cron yields only
   `{0, 4}`, leaving six desks never leading. Test pins it.

Cron went hourly → `0 */4 * * *`, at the owner's instruction to keep it
but slow it. Hourly was actively harmful: a 429'd match persists as
`translationState=fallback` and is retried by every later run, so ~100
poisoned entries re-killed the quota shortly after each reset.

Coverage moved 36 → 53 → 72 across the session. The final verification
run returned **zero** fresh matches — four manual runs in 90 minutes had
burned the day's budget, which is the same failure mode as the hourly
cron, self-inflicted. Ten days later, on the 4-hourly cron, it reached
111/111.

Key env vars were also made additive rather than a `||` precedence
chain, so `GEMINI_API_KEYS` no longer silently disables
`OPENAI_API_KEY`. Writing the owner's key into a repo secret was
attempted and correctly blocked by the permission layer; the owner was
given the command instead and, as it turned out, never needed it.

## 2026-08-24 — icon sizing, network permission, localized app name

**v1.2.1 → v1.2.4.**

The release APK had **no `INTERNET` permission**: the Flutter template
declares it only in the debug and profile manifests, so release builds
silently had no network and showed nothing but the bundled snapshot.
Three versions of "why is the data stale" turned out to be this. Found
by screenshotting the device after the owner said "你可以自己看"; not
visible in any build log.

Also: `app_version.dart` carried a hardcoded `1.1.6`, so the app
misreported itself whenever a build skipped the release script.

The Android icon was being shrunk twice — a generated
`<inset android:inset="16%">` on top of the launcher's own 66.7% safe
zone — so the mark looked tiny on the Mi Pad. `generate_icon.py` now
sizes the foreground by what actually survives both, verified by
cropping a screenshot of the device's dock.

The display name now follows the device language rather than being
fixed, via `values-zh/strings.xml` on Android and localized
`InfoPlist.strings` on iOS and macOS.

## 2026-08-23 — renamed from News Insights to News Insight

Folder, Dart package, GitHub repo and bundle id all became
`yahwehs_world` / `com.yswords.yahwehsworld`. **The Netlify site and its
URL were deliberately not renamed** — `news-insight.netlify.app` stays,
because links exist. Saved-preference keys stayed `newsInsights.*` for
the same reason: renaming them resets every existing install.

Verse relevance was improved by fetching the article body *before* the
deep-match call, so the model reads a 700-char excerpt rather than a
headline and one-line RSS summary, and must return a `whyRelated`
justification. The corpus grew to 159 verses.
