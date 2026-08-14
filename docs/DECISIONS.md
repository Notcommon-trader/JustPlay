# Decisions

Choices that were genuinely open, the reasoning at the time, and what would reopen them. A decision
without a stated reason cannot be revisited intelligently — the next person only sees the outcome and
has to guess whether it was considered or accidental.

Decisions about *structure* live in ARCHITECTURE.md next to what they constrain. This file is for
the ones that cross-cut: vendors, policy, and money.

---

## Backend: Firebase, not Supabase — decided 2026-08-14

**Firebase.**

Supabase is the better product in the abstract — real Postgres, SQL, self-hostable, no lock-in. None
of that is what this app needs, and one thing it lacks is something this app cannot do without.

- **Offline-first is non-negotiable here** (ARCHITECTURE.md §6: casual play happens on commutes and
  in queues). Firestore ships a mature, first-party offline cache on mobile that has been in
  production for years. Supabase has no equivalent — the offline story is client libraries plus your
  own queue and conflict resolution. Building that is weeks of work whose failure mode is silently
  losing a player's progress.
- **Remote Config has no Supabase counterpart.** ARCHITECTURE.md §7 already commits to ad frequency
  living in remote config rather than code, so that tuning monetisation never requires a release.
  Rebuilding it on Supabase means a config table, a fetch, a cache, and a default-on-failure path.
- **AdMob, Play Billing, Crashlytics and Analytics are all Google.** One console, one SDK
  initialisation, one consent flow. With Supabase the auth and data live somewhere the ad and
  billing stack cannot see, and every join between "who paid" and "who saw an ad" becomes our code.
- **Cost at this scale is zero either way**, so price is not a tiebreaker. It becomes one only at a
  volume this business has not reached.

**What we give up:** SQL, portability, and a self-hosting escape hatch. Firestore's query model will
feel cramped the first time a statistics screen wants a real aggregate.

**What would reopen this:** a statistics or leaderboard feature that Firestore genuinely cannot
express, or a second business line where data portability is a contractual requirement. Note that
the local layer is already behind a `KeyValueStore` port, so *local* storage is not part of this
lock-in — only sync is.

---

## Play target audience: 13+, not Families — decided 2026-08-14

**Declare 13+ and up. Do not opt into the Families programme.**

The games — 2048, sudoku, solitaire, minesweeper, word search, nonogram — are genuinely general
audience rather than child-directed. That makes the declaration honest, which is the part that
matters: Play does not take the age declaration at face value, and an app whose branding, art or
listing appeals to children is held to Families policy whatever the form says.

**Why not opt in:**

- Families forbids personalised ads to children and requires every ad SDK to be on Google's
  self-certified list. Personalised ads are a large multiple of non-personalised revenue in casual
  games, and forfeiting that on a bundle nobody markets to children is paying a real cost for a
  badge.
- It adds a content-rating and design review to every one of the two releases a month, which is
  precisely the cadence this whole architecture exists to protect.
- Ad ID access is restricted, which affects attribution and any future user-acquisition spend.

**What we give up:** the Play Store "Kids" tab and any teacher/parent curation. That was never the
acquisition channel — for a casual puzzle bundle, category browsing and search are.

**What this obliges us to do:** keep the app honestly non-child-directed. Cartoon mascots, primary
colours, playground language or a listing pitched at kids would all make the 13+ declaration wrong
and the app non-compliant, not merely mis-tagged. The current Material 3 look is comfortably clear
of this.

**What would reopen this:** a deliberate decision to build a children's title. That is a different
app with a different design, not a re-tag of this one.

---

## Local storage: key-value port, not Isar — revised 2026-08-14

Recorded in ARCHITECTURE.md §6, where it constrains the code. Summary: what the app persists is one
small JSON record per game, so a database would have bought build tooling and native binaries against
a need that has not arrived. The `KeyValueStore` port keeps the swap cheap.

---

## Stack: Flutter, not Unity — decided 2026-08-10

Recorded in ARCHITECTURE.md. Summary: a completed Unity build read as rudimentary and unshippable;
Flutter gives a modern-looking app for free, and ~8 of 10 games in this catalogue need no game engine
at all.
