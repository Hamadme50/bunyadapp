# Play Store listing copy

Paste into **Play Console → Grow → Store presence → Main store listing**.
Character counts are checked against Play's limits at the time of writing.

---

## App name (30 max)

```
Bunyad — Construction Expenses
```

`30 / 30`

> If Play objects to the em dash, use `Bunyad: Construction Expenses` (29).

---

## Short description (80 max)

```
Every rupee your building costs — stage by stage, with the bill attached.
```

`73 / 80`

**Alternative, if you want the category word earlier for search:**

```
Construction expense tracker: every rupee, stage by stage, bill attached.
```

`73 / 80`

---

## Full description (4000 max)

```
Building a house costs more than anyone plans for, and the reason is almost never one big number — it is a thousand small ones nobody wrote down. Bunyad is the book for those numbers.

Set up your project, walk it through the stages a build actually goes through, and log what each one costs as it happens. Photograph the bill while you are standing there. Months later, you will still know what the sariya cost in the third lot and who you bought it from.

WHAT YOU CAN DO

• Keep a project per build, with the plot size in Marla, Kanal, Sq ft, Sq yd, Acre or Bigha
• Work through the stages of a real build — Plot, Foundations, Grey Structure floor by floor, then Finishing — and rename, reorder or remove any of them
• Log an expense in seconds: what it was, how much of it, from which vendor, for how much, on what date
• Record quantities the way the site talks — bags, trolleys, trips, man-days, pieces — and weights that add up across units
• Group spending under your own headings, so Cement, Sariya, Labour and Sanitary each carry their own total
• Attach photographs of bills and delivery slips, straight from the camera or your gallery
• Watch totals roll up automatically, per stage and across the whole project
• Add notes to anything that needs explaining later

SHARE IT WITH THE PEOPLE WHO NEED IT

Building is rarely a one-person job. Invite your contractor, your brother, your site supervisor — as an editor who can log expenses, or as a viewer who can only read. You stay the owner, and you can take access back whenever you like.

BUILT FOR THE SITE, NOT THE DESK

Bunyad is meant to be used standing in the dust with one hand free. Big targets, short forms, and a camera button where you expect it. Amounts are shown in full so you can read them at a glance — no rounding your money into "1.2L".

HONEST ABOUT YOUR DATA

Bunyad carries no advertising, no analytics and no tracking of any kind. There are no third-party SDKs in the app. What you enter goes to the Bunyad server and stays there — nothing is sold, and nothing is shared with anyone except the people you personally invite onto a project.

You can delete your account from inside the app at any time, and it takes your projects, your expenses and your photographs with it. Read the full policy at https://bunyadapp.com/privacy

WHO IT IS FOR

Anyone paying for construction and tired of guessing: people building their own house, small contractors running two or three sites, families keeping each other honest about a shared build, and anyone who has ever tried to reconstruct six months of spending from a shoebox of receipts.

Bunyad — every rupee your building costs, in one book.
```

`2,668 / 4000`

---

## Graphics checklist

| Asset | Spec | File | Built |
| --- | --- | --- | --- |
| App icon | 512 × 512 PNG, no alpha | `store/app-icon-512.png` | 512 × 512 RGB |
| Feature graphic | 1024 × 500 PNG, no alpha | `store/feature-graphic-1024x500.png` | 1024 × 500 RGB |
| Phone screenshots | 2–8, sides 320–3840px, ratio ≤ 2:1 | `store/screenshots/phone/` | 5 × 1080 × 1920 (1.78:1) |
| 7-inch tablet | up to 8, same limits | `store/screenshots/tablet7/` | 5 × 1200 × 1920 (1.60:1) |
| 10-inch tablet | up to 8, same limits | `store/screenshots/tablet10/` | 5 × 1600 × 2560 (1.60:1) |

Upload the files in `screenshots/<class>/` — those are the finished, captioned
images. `screenshots/raw/<class>/` holds the unframed emulator captures they
were built from; keep them, they are the source for any recut.

Note the phone raws are 1080 × 2424, which is steeper than the 2:1 Play allows.
Compositing onto a 9:16 canvas is what brings them inside the limit — do not
upload a raw phone capture directly.

### Rebuilding

```bash
python store/make_graphics.py && python store/make_screenshots.py
```

Captions live in `CAPTIONS` at the top of `make_screenshots.py`. To recapture a
screen, put the emulator on it and run:

```bash
powershell -File store/capture.ps1 -Name 02-project
```

That writes all three device classes in one pass, resizing the emulator with
`wm size`/`wm density` rather than needing separate tablet AVDs.

---

## App Store Connect

The App Store asks for fields Play does not. Name and full description carry
over unchanged; these three are extra.

### SKU

```
com.bunyad.expense
```

Internal only — never shown to anyone, used to identify the app in your sales
and finance reports. It must be unique across your account and **cannot be
changed once the app record is created**, so it is worth getting right first
time. Matching the bundle identifier is the usual convention and makes reports
trivial to reconcile. `bunyad-ios-001` is equally valid if you would rather keep
the two identifiers visibly separate.

Note this is an *App Store Connect* field. Google Play has no app-level SKU —
there, `com.bunyad.expense` is the package name, and "SKU" only ever refers to
in-app products.

### Subtitle (30 max)

```
Construction expense book
```

`25 / 30`

### Keywords (100 max)

Comma separated, **no spaces after the commas** — a space costs a character.
Do not repeat words already in the name or subtitle; Apple indexes those anyway.

```
sariya,cement,builder,contractor,site,budget,material,vendor,bill,receipt,house,ledger
```

`85 / 100`

### Promotional text (170 max)

Editable without submitting a new build, so it is the field to change when
something is worth announcing.

```
Log what your build costs while you are standing on site — the amount, the vendor, and a photo of the bill. Totals add themselves up, stage by stage.
```

`146 / 170`

### Screenshot sizes

| Size | Required | Folder |
| --- | --- | --- |
| iPhone 6.9" — 1320 × 2868 | Yes | `store/screenshots/ios-6.9/` |
| iPad 13" — 2064 × 2752 | Yes, because the project targets iPhone **and** iPad | `store/screenshots/ios-ipad-13/` |

6.5" and 5.5" iPhone sets are no longer needed — Apple scales the 6.9" set down.
Drop iPad support in Xcode (`TARGETED_DEVICE_FAMILY = "1"`) and the iPad set
stops being required.

## The five shots

Filenames carry the order Play displays them in, so the sequence is the pitch.
All five are built from one seeded demo project — a 10 Marla house in DHA Phase
6 at Rs 17,043,000 across 7 expenses.

| # | Screen | Caption |
| --- | --- | --- |
| 01 | Dashboard — portfolio total and the project card | Every rupee your building costs |
| 02 | Project header — total, team, first stage | Watch the total build itself |
| 03 | Stage ladder — per-stage totals and progress | Stage by stage, floor by floor |
| 04 | Stage timeline — three entries under their heads | Every purchase, logged on site |
| 05 | Account — privacy links and delete account | No ads. No tracking. Your data stays yours. |

Captions are deliberately limited to what each picture actually shows. Two
screens worth adding later, once there is demo data for them: a bill photograph
full-screen, and the share sheet inviting an editor.
