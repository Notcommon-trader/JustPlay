# Data Safety — console answer sheet

Play's Data Safety form, answered for the current build. Work down it in order;
every answer below is a click, not a judgement call you have to make live.

**These answers are only correct while the app collects nothing.** Adding AdMob
changes almost every one of them — an ad SDK collects the advertising ID and
device information whether or not you write any code to do so. Re-do this form
in the same release that adds ads, not after.

---

## Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | *(skipped — nothing is collected)* |
| Do you provide a way for users to request that their data is deleted? | *(skipped)* |

Answering **No** to the first question closes the entire form. It is the correct
answer here: data stored only on the device, never transmitted off it, is not
"collected" under Play's definition. Google states this explicitly — on-device
storage that the developer cannot access is out of scope.

## Why each category is No

| Category | Reason |
|---|---|
| Location | Never requested. |
| Personal info | No account, no name, no email. |
| Financial info | No purchases in this build. |
| Health and fitness | Not applicable. |
| Messages, photos, files, contacts, calendar | Never requested. |
| App activity | Best scores are stored on-device only and are not accessible to us. |
| Web browsing | The app has no browser and makes no requests. |
| App info and performance | No crash reporting, no diagnostics, no analytics SDK. |
| Device or other IDs | No advertising ID, no device identifier. |

## Content rating questionnaire

| Question | Answer |
|---|---|
| Violence, sexuality, language, controlled substances | **No** to all |
| User-generated content or user interaction | **No** — there is no chat, no sharing, no multiplayer |
| Shares user location | **No** |
| Digital purchases | **No** *(changes when IAP lands)* |
| Ads | **No** *(changes when AdMob lands)* |

Expected outcome: Everyone / PEGI 3.

## Target audience and content

| Question | Answer |
|---|---|
| Target age groups | **13–15, 16–17, 18+.** Tick no group below 13. |
| Does your app appeal to children? | **No** |
| Ads in your app | **No ads** *(for this release)* |

Selecting any under-13 group puts the app under the Families policy, which
forbids personalised ads and requires certified ad SDKs. That is a deliberate
decision, recorded with its reasoning in [DECISIONS.md](../DECISIONS.md).

The declaration has to stay honest: Play does not take the age answer at face
value and will hold an app to Families policy if its art or listing appeals to
children, whatever the form says.

## Government apps, financial features, health

**No** to all. None apply.

---

## What to redo when ads arrive

1. Data Safety: **Yes** to collection. Declare *Device or other IDs → Advertising
   ID*, purpose *Advertising*, and *App activity* if analytics ships alongside.
2. Data Safety: encryption in transit **Yes**, and provide a deletion request
   route.
3. Content rating: **Yes** to ads; re-run the questionnaire.
4. Target audience: declare ads present.
5. Update [PRIVACY_POLICY.md](PRIVACY_POLICY.md) and republish it at its URL
   **before** the release rolls out.
