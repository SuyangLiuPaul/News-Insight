# OPEN-ITEMS.md

Everything not done: bugs, unfinished work, decisions waiting on the
owner, and landmines. Each item says whether it was **verified** or is
**carried forward unchecked**, because the difference matters when you
are deciding what to trust.

Read `AGENTS.md` first. Last reviewed **2026-09-05**.

---

## 1. The nightly iOS reinstall cannot install to a locked device

**[carried forward]** — verified 2026-09-04 from
`/tmp/news-insight-ios-reinstall.log` for that day's 04:40 run. **Could
not be re-read on 2026-09-05:** the script does `exec > "$LOG" 2>&1`
(line 50), so the log is truncated each run and the file is simply absent
now; the plist's own `StandardOutPath`/`StandardErrorPath`
(`/tmp/news-insight-ios-reinstall.stdout.log` and `.stderr.log`) are
absent too. The diagnosis below is therefore carried forward on the
2026-09-04 reading, not re-confirmed.

Two adjacent facts **[verified 2026-09-05]**: the job is still loaded
(`launchctl list` shows `com.yahwehsworld.ios-reinstall`, last exit
status 0 — note it exits 0 even on the nights the iOS legs fail, so exit
status is not a health signal here), and the launchd copy at
`~/.config/news-insight/scripts/` is byte-identical to `tools/`
(md5 `afa7cc598cf206c65ca22de5d893a46b`), so the drift trap AGENTS.md
warns about has not sprung.

Both iOS devices failed. The build itself succeeded and the macOS leg
succeeded; only the two `devicectl install` steps failed:

```
kAMDMobileImageMounterDeviceLocked: The device is locked.
Failed to mount /Library/Developer/DeveloperDiskImages/iOS_DDI/...
```

The developer disk image cannot be mounted on a locked iPhone or iPad.
The job fires at 04:40, when both devices are locked and will stay
locked, so **the iOS half of this job is expected to fail every night**
— it is not a transient WiFi problem. The macOS leg is unaffected,
which is why `/Applications` is current at 1.2.6 while the phones are
not.

The script reports this as `(asleep, off WiFi, or unpaired)`, which is
wrong and sent an earlier investigation down the wrong path. That
message has been corrected to name the locked-device case.

**Not decided:** what to do about it. The options, none free:

- run `tools/news-insight-ios-reinstall.sh` by hand while holding an
  unlocked device — reliable, but manual every 7 days;
- move the job to a time the owner is normally awake and the device
  unlocked, accepting it will still miss some nights;
- accept macOS-only automation and treat iOS as manual.

This needs the owner's call. Until then the phones drift.

## 2. Verse quality has never been fairly assessed — MOOT

**[closed 2026-09-20]** The app no longer shows verses or reflections at
all (owner: 「所有ai评价和经文全部去掉 只看新闻就够了」), so there is no
verse in it to judge. What follows is kept as the record of why the
question was hard.

**[carried forward]** — never assessed, and not assessed on 2026-09-05
either. Judging verse quality is an editorial reading of live output,
not something a test can settle; it needs the owner or a deliberate
review pass.

The owner's original complaint — verses "not really related" — was
answered with a real fix (the model now reads a 700-char body excerpt
and must justify the pick in a `whyRelated` field, and the corpus grew
to 159 verses). But every subsequent look at output was taken while the
majority of stories were on **keyword fallback**, meaning the deep-match
prompt was not what produced them. Judging the prompt from those
editions was meaningless.

As of 2026-09-04 coverage is 111/111. This is the first honest
opportunity to evaluate. If verses still miss, the lever is the prompt
in `aiDeepMatch` and the corpus, **not** quota or cadence.

## 3. The GitHub release is two versions behind

**[verified 2026-09-05]** — `gh release list` still shows `v1.2.4`
(2026-08-24) as latest, against `pubspec.yaml` `1.2.6+16`.

The portal's download buttons all point at `releases/latest`. Anyone
downloading the Android APK, macOS or iOS build today gets 1.2.4:
pre-blue-theme, and without the Dart-side section ordering for the
Creation and Documentary desks. They would still see those desks, since
the filter chips come from the feed.

Closing it means building four artifacts and `gh release create v1.2.6`.

**Ready to close, deliberately not closed. [verified 2026-09-05]**
`tools/release_github.sh` (committed in `e18e711`) now does the whole job and
its `--dry-run` exited 0 when it was measured — and no longer does in the current tree, because HEAD is two commits ahead of origin/main and both the old and the new guards refuse that. That is the guard working, not a regression. All four artifacts sit verified in
`build/release-1.2.6/` — Android 59.5 MiB, macOS 30.3 MiB, Web 27.6 MiB,
iOS 20.6 MiB — and each was independently confirmed to carry the string
`1.2.6` (the APK checked per-ABI: arm64-v8a, armeabi-v7a and x86_64 all
carry it, twice each).

Publishing is the owner's call, so nothing was tagged or uploaded and
`gh release list` still reports v1.2.4 as latest. To close it: commit
the script, then run it without `--dry-run`.

## 4. `yswords-data/README.md` overstates the API-key advice — DONE

**[verified 2026-09-05] Does not reproduce.** The README's key passage
now reads that adding a key "turned out **not** to be necessary"
(`README.md:177`), keeps the ~58-call measurement as evidence, and ends
"Fix those first." (`README.md:180`). Nothing left to soften.

The phrase "highest-value lever" survives in `yswords-data` only inside
`AGENTS.md`'s own note recording that it is gone. An earlier revision of
this entry also placed it "in one archived news body" — that was wrong,
and searching for it is what proved it: `data/archive/2026-06-12.json`
matches only "highest-value", in an unrelated BBC story about a SpaceX
"highest-value stock listing". Note the phrase is line-wrapped in
`AGENTS.md`, so a single-line `grep "highest-value lever"` returns
nothing at all and reads as if the phrase were fully gone.

## 5. Two source feeds contribute little — RULED, both kept

**[verified 2026-09-05]** Re-measured across `data/daily_news.json`
plus all 79 `data/archive/*.json`, counting items by each item's
`source` field, and separately by direct RSS fetch with the pipeline's
own UA (`DailyMannaDispatchBot/1.0`). No pipeline run, no quota spent.

**State the denominator honestly: it is ONE, not eighty.** Only the
live `daily_news.json` has a `science` or `documentary` desk at all.
The 79 archived editions predate both desks and are not evidence either
way. Do not carry "0 across all 80 editions" forward — it is technically
true and materially misleading.

### `Nature` — keep. The unverified half is now answered.

Nature contributed **5 of the science desk's 26 items (19.2%)**, against
Phys.org 6, and BBC Science & Environment / ScienceDaily / Guardian
Science 5 each. The "weekly journal gets crowded out by same-day
sizing" hypothesis predicts under-representation; the measurement is
parity. Not a weak source, and the `maxItems: 26` override it motivated
is still doing its job. Leave both alone.

Caveat kept deliberately: n=1 edition, generated Saturday 2026-09-05,
two days after Nature's Thursday issue — close to a weekly's best case.
A Monday edition could look worse. Not grounds for action; noted so the
next reader does not over-read the 19.2%.

### `BBC Entertainment & Arts` — keep. Removal has no basis yet.

0 of the documentary desk's 10 items, and absent from that desk's
published `sourceNotes`. A direct fetch the same day returned **28
healthy items — no 403, no challenge page — containing zero `docu*`
word forms of any kind.** So the keyword filter never fires; the feed
is not broken.

That still does not justify removal, for a reason worth recording
because it nearly caused a wrong call:

> **A same-day probe is noisy, and this was measured, not assumed.**
> IndieWire scored **0** on the same probe while supplying **4 of the 10
> live items**. Checked per-item: all four match the current filter, and
> all four had already churned out of IndieWire's 12-item feed (published
> 1–8 days before the probe). So the probe method is sound — it agrees
> with the pipeline — but a 12-item feed's daily snapshot cannot detect a
> contributor that was real days earlier. A single zero cannot condemn a
> feed whose stated job is *periodic* coverage. At a true match rate of
> 2%, P(zero across 28 items) is still ~57%.

Also: the register's own precondition for acting — "worth a look if the
desks feel thin" — is not met. The desk carries 10 items from three
sources at full deep-match coverage — **123/123 measured on the live
2026-09-05 edition** (every item `translationState: 'localized'`, which
is the deep-matched state; the only other value is `'fallback'`). The
"111/111" figure elsewhere in these docs is the 2026-09-04 edition and
is simply older, not wrong. The feed costs one GET per run
and zero AI quota, since only items that reach a desk are deep-matched.

**Action taken:** none to behaviour. A comment now sits on the entry in
`sourceCatalog` (`yswords-data/scripts/refresh-news.mjs`) recording the
measurement, so the config stops implying the desk has four working
sources. The published `sourceNotes` was already honest.

**The measurement that would settle it** (nobody has run it): pull ~30
days of Wayback snapshots of the BBC E&A feed, dedupe by guid, apply the
same filter. ≥1 match in 30 days → keep, with a number. **0 in 30 days
of deduped items → removal becomes justified and costs nothing**, since
a feed that matched nothing for a month changes nothing by leaving.
Until then, removal is a publishing change on n=1 and is the owner's
call.

### Spun out of this: `'documentary'` does not match `'documentaries'`

**[verified 2026-09-05]** Substring `documentary` cannot match
`documentaries` (`documentar`+**ies**). Measured today across all four
documentary feeds, switching the token to the stem `'documentar'` gives
**delta +1**: Guardian Film 2→3, Guardian TV & Radio 3→3, IndieWire
0→0, BBC E&A 0→0. The one new item is a genuine documentary story (a
Bill Evans biopic by Grant Gee, "having directed documentaries about
David Bowie, Radiohead and Joy Division"). The stem is pollution-free —
unlike `doc` (matches "doctor", "documents"), `film` or `series`.

**Not shipped.** It admits items the pipeline currently excludes, so it
is a publishing change like any other and wants the owner's yes. Note
it does **not** rescue BBC E&A (+0) — the two questions are independent.

## 6. Unused UI strings — FIXED

**[verified 2026-09-05]** Reproduced, then fixed. All nine `section*`
keys were checked one at a time: `sectionAll` had exactly one reference
(`feed_page.dart:552`), and `sectionWorld`, `sectionChina`,
`sectionAustralia`, `sectionHongkong`, `sectionScience`,
`sectionTechnology`, `sectionCreation` and `sectionDocumentary` had
**zero** references anywhere in `lib/`. There is no dynamic key
construction to catch them either — every lookup in the app is a
literal `uiStrings['...']`, so nothing could have reached them at
runtime.

The eight dead entries are gone; `sectionAll` stays, and a comment in
their place records that every other chip label comes from the feed's
`categoryLabel` (`SectionChips`, `feed_page.dart`) — which is the reason
a desk added upstream shows up with no app release. `flutter analyze`
is clean and all 24 tests pass after the removal.

## 7. `yswords-data/README.md` step 4 still cites the old corpus size — DONE

**[verified 2026-09-05] Does not reproduce in the README.** Step 4 and
the dataset table both say 159 now, and `159` is the real count of
`verses` in `data/news_verse_corpus.json`. "24 topical categories" is
also correct — `_meta.categories` holds exactly 24.

The stale 149 had not vanished, though; it had moved somewhere the
README fix could not reach. `data/news_verse_corpus.json` itself carried
`"_meta": { "totalVerses": 149 }` against 159 actual entries. No code
reads that field and the schema types it only as `number`, so it passed
`npm run validate` while being plainly false. **Corrected to 159** in
the `yswords-data` working tree; `npm run validate` still passes.

## 8. No per-feed contribution counters, so "weak feed" stays an adjective

**[carried forward]** — proposed 2026-09-05, not built.

Item #5 took a full measurement pass to answer two feeds, and the answer
was still provisional because the only evidence available was one
edition plus a same-day RSS probe that turned out to be noisy. That cost
is going to recur for all 30 feeds every time someone asks this.

The pipeline already fetches and filters every feed on every run. If a
run logged, per source, `fetched / keyword-matched / published`, then
after 14 days (84 runs at the 4-hourly cron) every feed in
`sourceCatalog` would have a real base rate, and "contributes little"
would be a column rather than an adjective. This is a **non-publishing
change** — pure instrumentation, no effect on what readers see and no
AI quota — which makes it much cheaper to agree to than any feed edit.

Worth doing before anyone is asked to rule on a feed removal again.
