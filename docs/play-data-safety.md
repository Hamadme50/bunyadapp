# Play Console — Data Safety answers

What to enter in **Play Console → App content → Data safety**. Every answer here
matches what the app actually does, checked against the backend domain model and
the Flutter source. If the app changes, change this and the two public pages
together, or the listing goes stale.

Public pages backing these answers:

| Console field | URL |
| --- | --- |
| Privacy policy | `https://bunyadapp.com/privacy` |
| Account deletion URL | `https://bunyadapp.com/delete-account` |
| (Reference, not a console field) | `https://bunyadapp.com/data-safety` |

---

## Section 1 — Data collection and security

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — the release build is HTTPS-only; the cleartext exemption exists in the debug build only |
| Do you provide a way for users to request that their data is deleted? | **Yes** — in-app under Account → Delete account, plus the URL above |

---

## Section 2 — Data types

For every type below the answers to the four sub-questions are the same unless
noted:

- **Collected:** Yes
- **Shared:** No — nothing leaves the Bunyad server; there are no third-party SDKs
- **Processed ephemerally:** No — it is stored
- **Purpose:** App functionality, and Account management where marked

| Category | Data type | Required? | Purpose |
| --- | --- | --- | --- |
| Personal info | **Name** | Required | App functionality, Account management |
| Personal info | **Email address** | Required | App functionality, Account management |
| Personal info | **User IDs** | Required | App functionality, Account management |
| Personal info | **Other info** — vendor name and contact number the user types onto an expense | Optional | App functionality |
| Financial info | **Other financial info** — expense amounts, quantities and dates | Required | App functionality |
| Photos and videos | **Photos** — the bill or delivery slip attached to an expense | Optional | App functionality |
| App activity | **Other user-generated content** — project name, typed location, plot size, notes | Optional | App functionality |

### On the password

The form has no "password" data type, and Google does not ask you to declare
authentication credentials separately. It is stored only as a bcrypt hash and is
never readable. Nothing to select; it is documented on the public pages instead.

---

## Section 3 — Say NO to all of these

Do not tick any of them. None are collected, and a wrong tick here is what gets
a listing rejected:

- **Location** — approximate or precise. A project's "location" is a line of text
  the user types. The app holds no location permission and never asks the device
  where it is.
- **Device or other IDs** — no advertising ID, no device fingerprint.
- **App activity** — app interactions, in-app search history, installed apps,
  other actions. There is no analytics SDK.
- **App info and performance** — crash logs, diagnostics, performance. There is no
  crash reporter.
- **Financial info → User payment info / Purchase history / Credit score.** Bunyad
  records what the user says they spent; it never touches a payment instrument.
- **Contacts, Calendar, Messages, Audio, Files and docs, Health and fitness,
  Web browsing history.**

---

## Section 4 — Related declarations elsewhere in App content

| Item | Answer |
| --- | --- |
| Ads | No ads |
| Target audience | Adults (18+). Not directed at children — this keeps the app out of the Families policy |
| Data safety: independent security review | No |
| Government apps / financial features | No — an expense ledger is not a financial product; it moves no money |
| Permissions declaration | Camera is optional and used only through the system camera intent when attaching a bill. No sensitive permissions (no location, contacts, SMS, all-files access) |

---

## Why "shared" is No everywhere

Google defines *sharing* as transfer to a **third party**. When a Bunyad user
invites someone onto a project, both are users of the same app on the same
server — that is app functionality, not a transfer to a third party, and the
owner controls it. There are no analytics, advertising, or backend SDKs of any
kind in the build, so nothing is transferred anywhere else.
