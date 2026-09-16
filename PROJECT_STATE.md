# PROJECT_STATE.md

What is where, and what is queued. Update this in the same commit that
changes reality. Read `AGENTS.md` first.

Last verified: **2026-09-04**.

---

## Version, by surface

`pubspec.yaml` says **1.2.7+17**.

**1.2.7 exists for one reason: the Android release key.** Every APK up
to and including 1.2.6 was signed with the Flutter debug keypair — the
template's `signingConfig = signingConfigs.getByName("debug")` TODO,
still in place long after Yahweh's Sword (2026-08-25) and Yahweh's Words
(2026-09-09) had replaced theirs. That certificate reads
`CN=Android Debug, O=Android, C=US`, is shared by every Flutter install
on every machine, and anyone can forge an update to it. See the note at
the top of `android/app/build.gradle.kts` for where the keystore lives
and why the build falls back to debug signing rather than failing when
it is absent.

The cost, once: Android refuses an update signed with a different key,
so an existing 1.2.6-or-earlier install must be **uninstalled before
1.2.7 will install**. Done now rather than later because the number of
installs only grows.

| surface | version | how it was checked | when |
|---|---|---|---|
| web (`news-insight.netlify.app`) | **1.2.6** | `curl` the deployed `index.html` splash | 2026-09-04 |
| macOS (`/Applications/News Insight.app`) | **1.2.6** | `defaults read … CFBundleShortVersionString` | 2026-09-04 |
| iPhone 16 Pro Max | **unknown, ≤1.2.4** | last successful install was v1.2.4 on 2026-08-24; every nightly since has failed to install — see `docs/OPEN-ITEMS.md` #1 | 2026-09-04 |
| iPad Pro 11-inch | **unknown, ≤1.2.4** | same | 2026-09-04 |
| Mi Pad (Android) | **1.2.4** | `adb shell dumpsys` at install time on 2026-08-24; not re-checked since | 2026-08-24 |
| GitHub release `latest` | **1.2.7** | `releases/latest` redirects to `tag/v1.2.7`; the published `NewsInsight-Android.apk` was downloaded and `apksigner` printed `CN=Paul Liu, O=News Insight, L=Melbourne, C=AU`, SHA-256 `6aed5880…798cdcfa` | 2026-09-17 |

Gaps worth naming rather than hiding:

- **The release is current again.** That gap — `releases/latest` serving
  1.2.4 while the code was on 1.2.6 — was closed on 2026-09-16, and
  1.2.7 followed on 2026-09-17. The download buttons on
  https://yahwehword.com/about point at `releases/latest`, so they need
  no edit when a version ships.
- **No native surface has been confirmed on 1.2.7.** The macOS copy
  tracks the nightly job; both iOS devices are stuck on whatever they
  last accepted; the Mi Pad still has a **debug-signed 1.2.4** and will
  refuse 1.2.7 until it is uninstalled once.

---

## The pipeline, as measured

**Latest reading — edition `2026-09-05`, generated
`2026-09-05T11:40:29.858Z`, measured 2026-09-05 off the checkout:**

```
world         18/18      science       26/26
china         10/10      technology    18/18
australia     11/11      hongkong      18/18
creation      12/12      documentary   10/10

123 stories, 123 deep-matched, 0 keyword-fallback
```

Still full coverage on every desk, on the one API key. Beware when
re-measuring: the field is `translationState` and its deep-matched value
is **`'localized'`**, not `'deep'` (`refresh-news.mjs:2102`); the schema
permits only `'localized'` and `'fallback'`. Counting `=== 'deep'`
reports zero coverage on a perfectly healthy edition.

The earlier reading below is kept for the trend, not because it is
current.

Live feed at `yswords-data.netlify.app/data/daily_news.json`,
edition `2026-09-04`, generated `2026-09-03T22:06:23Z`:

```
world         18/18      science       26/26
china         10/10      technology    13/13
australia     10/10      creation      14/14
hongkong      10/10      documentary   10/10

111 stories, 111 deep-matched, 0 keyword-fallback
```

**Full coverage, every desk.** For context on why that is worth
recording: on 2026-08-25 the same pipeline was at 72/132 with the last
three desks near zero.

### What actually fixed it

Four changes compounded, on a **single API key**:

1. default model off `gemini-2.5-flash` (~20/day) onto `-flash-lite`
2. removing the `refresh.yml` `env:` pin that was overriding (1)
3. `OPENAI_MODEL_CHAIN` step-down on 429/5xx instead of same-model retry
4. cron hourly → `0 */4 * * *`, plus `rotateSectionOrder` so no desk is
   permanently last

Recent runs complete in 10–17 minutes and succeed.

### A recommendation that turned out to be wrong

During debugging it was asserted that adding a second API key was "the
highest-value lever" and the owner was given a command to run. **They
did not run it, and it was not needed** — `gh secret list` shows only
`OPENAI_API_KEY` to this day. Capacity was never the binding constraint
once the model chain and cadence were right.

The code change that accompanied that advice is still correct and worth
keeping: the three key env vars are now additive rather than a `||`
chain, so if a second key is ever added it will genuinely add capacity
instead of silently disabling the first.

---

## Queue

Nothing is in flight. Candidates, roughly by value:

1. **Cut a v1.2.6 GitHub release** so the portal's download link stops
   serving 1.2.4. **Now one command away.** `tools/release_github.sh`
   exists (still untracked), its `--dry-run` exits 0, and all four
   artifacts are built and verified in `build/release-1.2.6/`, each
   confirmed to carry `1.2.6` — the APK per-ABI. Not published, because
   publishing is the owner's call: `gh release list` still shows v1.2.4.
   To close: commit the script, then run it without `--dry-run`.
2. **Get the iOS devices back on a current build** — see
   `docs/OPEN-ITEMS.md` #1. Needs the owner present with a device
   unlocked, or a change of approach.
3. **Judge verse quality now that coverage is 100%.** Every earlier
   attempt to assess this was confounded: most stories were on keyword
   fallback, so the deep-match prompt was never really being read. This
   is the first time the question can be asked honestly. If the verses
   are still weak, the lever is the prompt in `aiDeepMatch`, not quota.
4. ~~**`yswords-data/README.md` overstates the key advice.**~~ Checked
   2026-09-05: already softened. The README now says a second key
   "turned out **not** to be necessary" and keeps the measurement as
   evidence rather than as a recommendation. See `docs/OPEN-ITEMS.md`
   #4 and #7 — the only stale number that survived was
   `news_verse_corpus.json`'s `_meta.totalVerses` (149 vs 159 actual),
   corrected in the `yswords-data` working tree.
5. ~~**Two weak news sources.**~~ Ruled 2026-09-05, both kept — see
   `docs/OPEN-ITEMS.md` #5. `Nature` measured at 5/26 science items, at
   parity with its four peers, so the "weekly gets crowded out" worry is
   answered. `BBC Entertainment & Arts` has never contributed, but the
   honest denominator is **one** edition, and a same-day probe was shown
   to be noisy (IndieWire probed 0 while supplying 4 of 10 live items).
   No behaviour changed; a comment now records the measurement in
   `sourceCatalog`. Removal stays the owner's call and wants a 30-day
   Wayback base rate first.
6. **Two measured, unshipped proposals** now sitting in
   `docs/OPEN-ITEMS.md`, both needing the owner's yes:
   #5 — widen the documentary filter to the stem `'documentar'`, since
   `'documentary'` cannot match `'documentaries'` (measured delta: +1
   item, genuine, across all four desk feeds); and
   #8 — log per-feed `fetched / matched / published` counters, a
   non-publishing change that would turn "contributes little" from an
   adjective into a column for all 30 feeds.
