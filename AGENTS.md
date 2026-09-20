# AGENTS.md — start here

This file is the entry point for anyone, human or AI, picking up
News Insight. Read it before touching anything. It is deliberately
short; everything it points at is longer.

News Insight (新闻洞见) is a Flutter news reader — the news and nothing
else. Since 2026-09-20 (「所有ai评价和经文全部去掉 只看新闻就够了」) it shows
no commentary and no Bible verse, and it runs no AI of its own: the feed
it reads still carries a verse and a reflection per story, and
`NewsArticle` does not parse them, so nothing can render them. Do not add
them back without the owner asking.

The pipeline that produced that feed was stopped the same day
(`yswords-data`'s `refresh.yml`: the schedule is commented out,
`workflow_dispatch` remains), so the feed is now a fixed last edition
rather than a moving one.
It ships to web, Android, iOS and macOS from one codebase, in English
and 简体中文.

**It is a client, not a pipeline.** The app does no scraping, no AI and
no translation. All of that lives in a second repo, `yswords-data`, and
the app reads its published JSON. You will spend more time in the
pipeline than in the app. See "The two repos" below.

---

## The five minutes that save you a day

**Flutter is not on PATH.** It lives at `/Users/pliu0036/flutter/bin/flutter`.
Every command below spells it out.

```bash
/Users/pliu0036/flutter/bin/flutter analyze     # must be clean
/Users/pliu0036/flutter/bin/flutter test        # ~5s, 24 tests as of 1.2.6
tools/release_web.sh                            # build + deploy web (prod)
tools/release_web.sh --build                    # build only, no deploy
tools/news-insight-ios-reinstall.sh            # iPhone + iPad + this Mac
```

There is only one web site and it is production. `release_web.sh` stamps
the version into both the Dart side and the boot splash from
`pubspec.yaml`, so those two can never disagree — **never run a bare
`flutter build web` for a release**, or the splash ships the literal
string `__APP_VERSION__` and the header shows `dev`.

**Where truth lives, and what each document is for:**

| file | what it is |
|---|---|
| `AGENTS.md` | this file — the contract |
| `PROJECT_STATE.md` | what version is where, and the queue |
| `docs/OPEN-ITEMS.md` | **everything not done** — bugs, unverified claims, decisions waiting on the owner |
| `HANDOFF.md` | append-only log, newest on top, one entry per ship |
| `README.md` | GitHub-facing description; allowed to drift, least trustworthy |

When two documents disagree, **the tree wins, then `HANDOFF.md`**.

---

## The two repos

| repo | path | what it owns |
|---|---|---|
| `News-Insight` | `~/Documents/CodingProject/News-Insight` | this app — rendering, caching, locale, icons, releases |
| `yswords-data` | `~/Documents/CodingProject/yswords-data` | RSS ingest, verse deep-match, translation, the published JSON |

A third repo, `yswords-apps` (`~/Documents/CodingProject/yswords-apps`,
branch **`master`**, not `main`), is the public portal listing this app
alongside its two siblings. It has a hand-written desk list that goes
stale whenever desks change.

The contract between app and pipeline:

```
https://yswords-data.netlify.app/data/daily_news.json        today's edition
https://yswords-data.netlify.app/data/archive/<date>.json    90-day scrollback
```

Shape is pinned by `yswords-data/schemas/daily_news.schema.json` and
validated in that repo's CI. The app parses leniently and **appends
unknown sections rather than dropping them**, which is why a new desk
appears in the app with no app release at all.

---

## Rules that are not negotiable

Each one is here because breaking it cost something real.

**Do not change any URL, route, package id, or Netlify site id.** The
web site is `news-insight.netlify.app` — an old name the owner
deliberately kept through the rename, because links exist. The bundle id
is `com.yswords.yahwehsworld` on every platform.

**Do not rename the saved-preference keys.** They are still
`newsInsights.locale` and `newsInsights.themeMode` in
`lib/models/app_settings.dart`. Renaming them silently resets every
existing install's settings. This is not an oversight to tidy up.

**Commit messages carry no attribution lines** — no `Co-Authored-By`,
no tool credit, nothing.

**Never `git add -A`.** These checkouts are shared with other sessions.
Stage the files you changed, by name.

**Secrets never get printed or committed.** They live in
`~/.config/yswords/secrets/` (mirrored to `~/Documents/secure-keys-backup/`).
Writing one into a GitHub Actions secret needs the owner's explicit
say-so naming that credential — a general "ok" is not enough, and the
permission layer will stop you anyway.

**Never invent a date, a number, a commit SHA, or a scripture
reference.** If you could not measure it, say so.

---

## The four traps that have cost the most time

### 1. The release build had no network permission for three versions

The Flutter Android template declares `INTERNET` only in the **debug and
profile** manifests. A release APK therefore had no network at all: the
feed never loaded and the app showed nothing but its bundled snapshot,
looking for all the world like a stale-data bug. It is now declared
explicitly in `android/app/src/main/AndroidManifest.xml` — leave it
there.

The wider lesson, and the reason this took three versions to find:
**build logs and a green analyze prove nothing about a device.**
Screenshot the running app. Every real bug in this project's history was
found by looking at a screen, not at a log.

### 2. A model's advertised quota was wrong by ~75×

The pipeline defaulted to `gemini-2.5-flash` on a comment claiming
1500 requests/day. Measured on a run fired three minutes after the
midnight-PDT quota reset — an untouched daily budget — it managed
**15 successful deep-matches and 429'd on the other 92**. The real free
tier is roughly 20/day. No cadence, cache or retry policy could ever
have covered a 130-story edition on it.

Two things follow, and both are now in the code:

- Retrying a model that just 429'd is the one strategy guaranteed to
  fail, because a per-day cap cannot be waited out. `callGeminiChat`
  walks `OPENAI_MODEL_CHAIN` and steps **down to the next model**.
- A `.github/workflows/*.yml` `env:` line silently overrides a script
  default. The first attempt at this fix changed the script and did
  nothing, because `refresh.yml` pinned `OPENAI_MODEL`. If a config
  change appears to have no effect, **grep the workflow before
  re-reading the script.**

### 3. Whatever sorts last, starves

Sections were built in a fixed order and the AI budget was spent as the
loop went. Coverage tracked processing position exactly: world 18/18,
china 10/10, australia 16/16, then science 2/26, technology 1/18,
creation 3/18. A fixed order does not ration a scarce budget — it
always starves the same desks.

`rotateSectionOrder` now advances the starting desk once per 4-hour
window. It is derived from **absolute time, not hour-of-day**: with a
4-hourly cron, `hour % 8` yields only `{0, 4}`, so six of the eight
desks would never lead. There is a test pinning exactly that.

### 4. Cadence turned one bad run into a permanent one

A deep-match that 429s is persisted as `translationState=fallback` and
**retried by every later run**. At the old hourly cron, ~100 poisoned
entries cost ~200 calls an hour and re-killed the daily quota within an
hour or two of each reset. The cron is now `0 */4 * * *`.

**Do not put it back to hourly.** Do not fire manual `workflow_dispatch`
runs in quick succession either — four runs in 90 minutes burned a whole
day's budget during debugging, and the day's last run achieved zero
fresh matches.

---

## How this codebase writes comments

Comments state **why**, with measured numbers, in full sentences, and
often name what was tried and failed. They are the project's memory.

```dart
/// Chip label for the section filter bar. Falls back to the desk
/// title for pre-categoryLabel snapshots (this file stays import-free,
/// so no ui_strings lookup here — the title is always present anyway).
```

```js
// Deliberately derived from absolute time rather than hour-of-day: with
// a 4-hourly cron, `hour % 8` only ever yields two distinct offsets, so
// six of the eight desks would never lead.
```

Do not write comments that restate the code. Do write down the number
that made you choose, and the alternative you rejected. Match the
density of the file you are editing. When you make a document false,
fix it in the same commit.

---

## Layout

```
lib/
  constants/  app_version.dart — reads --dart-define, defaults to "dev"
  models/     news_article.dart is the feed's shape + the section order
              list; app_settings.dart owns the prefs keys
  pages/      feed_page.dart (list + filter chips), article_detail_page
  services/   remote_data_service.dart — fetch, cache, archive paging
  theme/      app_theme.dart (ONE seed colour), ui_strings.dart (EN/ZH)
  utils/      pure functions — relative time
  widgets/    article_card, retry_network_image
```

`lib/theme/app_theme.dart` holds a single `_seed` colour and Material 3
derives the whole light and dark palette from it. Changing that one
constant restyles the entire app — there are no hardcoded colours
anywhere else in `lib/`, and it should stay that way.

The app name is **not** hardcoded per platform. It follows the device
language through `android/app/src/main/res/values-zh/strings.xml`,
`ios/Runner/zh-Hans.lproj/InfoPlist.strings` and the macOS equivalent.
If you add a locale, all three need it.

---

## Deploying

| target | where |
|---|---|
| web (prod) | `news-insight.netlify.app`, Netlify site `410313ea-f47e-4cda-872a-fa857581993d` |
| data | `yswords-data.netlify.app`, Netlify site `e1252e5a-a37e-4ba4-94ab-046ee9e6da9b` |
| portal | `suyangliupaul.github.io/yswords-apps` (branch `master`) |
| releases | `gh release` on `SuyangLiuPaul/News-Insight` |

The `netlify` CLI is borrowed from
`~/Documents/CodingProject/SmartHome/node_modules/.bin/netlify`.

Devices, by hardware udid:

| device | id |
|---|---|
| iPhone 16 Pro Max | `9FA8108D-E7E4-58F5-8326-3BD835C3A5E7` |
| iPad Pro 11-inch | `D5B9E2F7-F74E-5F8A-8A08-83008BDBD13C` |
| Mi Pad (Android) | `0907E41001A00540` |

A launchd job, `~/Library/LaunchAgents/com.yahwehsworld.ios-reinstall.plist`,
runs the reinstall nightly at 04:40 because the free iOS signing
certificate expires every 7 days. **The script it runs is a copy at
`~/.config/news-insight/scripts/`, not the one in `tools/`** — launchd
is blocked by TCC from reading `~/Documents`, and Full Disk Access does
not lift it. Edit both, or the job silently runs the old one. They are
in sync as of 2026-09-04.

See `docs/OPEN-ITEMS.md` for why the iOS half of that job does not
currently succeed.

---

## Working with the owner

The owner writes in Chinese and English, often briefly. Settled things,
not to be relitigated:

- Answer in the language the owner used.
- A number beats an adjective. "15 successful calls on an untouched
  daily budget" is worth more than "the quota seems low".
- Report what is not done as plainly as what is. If a fix is partial,
  say which part. If you burned something to learn something, say so.
- Verify on the real surface. The owner's "你可以自己看" (go look
  yourself) is what turned a three-version mystery into a one-line fix.
- Do not launch subagents, workflows or deep research unless asked.
