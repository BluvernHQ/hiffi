# Hiffi — Versioning & Release Consolidation Strategy (Draft)

**Status:** Draft for review  
**Audience:** Engineering, Product, QA  
**Requested by:** Hemangi / Bala  
**Contributors:** Sanjeev (mobile baseline), Engineering  

---

## 1. Purpose

This document proposes a **single versioning model** across **mobile (Android / iOS)** and **web**, and explains how we **consolidate all changes for a release into one version** so we can:

- Ship predictably to stores and production web
- Trace any build back to exact code (git tag + branch)
- **Roll back** to a known good version when needed
- Align QA, release notes, and backend compatibility per version

---

## 2. Current state (baseline)

| Area | Today |
|------|--------|
| **Mobile** | Semantic version + monotonic build in `pubspec.yaml` (e.g. `1.0.0+47`). Android `versionName` / `versionCode` and iOS `CFBundleShortVersionString` / `CFBundleVersion` derive from this. |
| **Store releases** | Play App Bundle / TestFlight builds tied to `version` + `+build`. Release notes maintained separately (e.g. `RELEASE_NOTES_PLAYSTORE.md`). |
| **Git** | `main` (integration), `production` (deployed / store-aligned). Version bumps typically land on the branch used for release. |
| **Web** | No formal version aligned with mobile yet; Sanjeev proposed adopting the **same scheme from the next web update**. |

**Gap:** Mobile and web can drift; there is no mandatory **version branch** or **tag** per store release; rollback relies on knowing which commit was shipped.

---

## 3. Version number format (recommended)

Use **Semantic Versioning** for the user-visible version, plus a **build number** for stores:

```
MAJOR.MINOR.PATCH+BUILD
Example: 1.2.0+48
```

| Part | Meaning | When to bump |
|------|---------|----------------|
| **MAJOR** | Breaking UX, incompatible API contract, forced migrations | Rare |
| **MINOR** | New features, notable UI changes | Each planned release |
| **PATCH** | Bug fixes, crash fixes, copy/placeholder tweaks, no new features | Hotfix / small store update |
| **BUILD** | Every binary uploaded to Play / App Store / internal QA | **Every** store/web deploy (never reuse) |

**Rules**

1. **BUILD always increases** (even for PATCH on the same `1.0.0`).
2. **MAJOR.MINOR.PATCH** is what users see in settings / about / web footer.
3. **Web** displays the same `MAJOR.MINOR.PATCH` (build optional in admin/debug only).
4. One **release version** = one git tag + one row in the release log (see §6).

---

## 4. Branching strategy

### 4.1 Long-lived branches

| Branch | Role |
|--------|------|
| `main` | Day-to-day integration; feature PRs merge here. |
| `production` | What is (or will be) live in prod / last store submission. Updated only via controlled merges from release branches or hotfix branches. |

### 4.2 Version branches (new — per Sanjeev)

For each **released** `MAJOR.MINOR.PATCH`, create and keep:

```
release/1.0.0
release/1.1.0
release/1.2.0
```

**Purpose**

- **Rollback:** Check out `release/x.y.z`, rebuild, redeploy (mobile binary or web artifact).
- **Hotfix:** Branch `hotfix/1.0.1` from `release/1.0.0`, merge fix → tag `v1.0.1` → merge to `production` and `main`.

**Lifecycle**

1. When starting a release candidate: `release/1.1.0` cut from `main` (freeze except release fixes).
2. QA validates builds from that branch only.
3. On go-live: merge `release/1.1.0` → `production`, tag `v1.1.0`, bump `pubspec` on `main` to next dev version (e.g. `1.2.0+49`).

### 4.3 Tags

Every production deploy (mobile or web) gets an annotated tag:

```
v1.1.0          # user-facing version
v1.1.0+48       # optional: include build if mobile binary-specific
```

Tag message template: store build IDs, web deploy ID, release notes link.

---

## 5. Consolidating releases into one version

A **version** is not a single PR—it is a **bundle** of work that ships together.

### 5.1 Release train (suggested cadence)

| Cadence | Contents |
|---------|----------|
| **Minor release** (e.g. bi-weekly / monthly) | Features merged to `release/x.y.0`, full regression, store + web same week where possible |
| **Patch / hotfix** | Critical bugs only; branch from `release/x.y.z` |

### 5.2 What goes in a version

Maintain a **Release board** (Jira / Linear / GitHub Milestone) named exactly like the version, e.g. `v1.2.0`:

- All tickets **must** be in the milestone to ship in that version
- PR titles or labels: `release/1.2.0` or milestone link
- **No drive-by** merges into `release/*` without PM/tech lead approval after freeze

### 5.3 Freeze checklist (release candidate)

- [ ] `pubspec.yaml` version set to `x.y.z+build`
- [ ] `release/x.y.z` branch created; only approved fixes
- [ ] QA sign-off on RC build numbers (Android + iOS)
- [ ] Web deploy from same tag (or same commit as mobile RC)
- [ ] Release notes drafted (`RELEASE_NOTES_PLAYSTORE.md` + web changelog)
- [ ] Backend/API compatibility confirmed for this client version (if applicable)
- [ ] Crashlytics / analytics reviewed for RC

### 5.4 Ship checklist (go-live)

- [ ] Store submission (or staged rollout %) documented
- [ ] Web production deploy from tag `v1.x.y`
- [ ] Merge `release/x.y.z` → `production` → `main`
- [ ] Tag `v1.x.y` on the shipped commit
- [ ] Archive RC artifacts (AAB, IPA, web build hash) in release notes

---

## 6. Mobile vs web alignment

| Concern | Approach |
|---------|----------|
| **Same version string** | Web shows `1.2.0`; mobile `1.2.0+48` — same **1.2.0** for user communication |
| **Same release window** | Target shipping web **within 24–48h** of store approval (or same day for coordinated launches) |
| **Feature flags** | If web ships first, flags prevent users seeing APIs mobile does not support yet |
| **Rollback** | Mobile: previous store version / halted rollout; Web: redeploy previous tag from `release/x.y.z-1` |

**Web implementation (next update):**

- Expose `APP_VERSION` in build (env / CI) matching `MAJOR.MINOR.PATCH`
- Deploy from git tag, not floating `main`
- Changelog page or footer: `Version 1.2.0`

---

## 7. Version bump workflow (mobile — Flutter)

1. Decide release type (MINOR vs PATCH).
2. On `release/x.y.z` branch, edit `pubspec.yaml`:
   ```yaml
   version: 1.2.0+48   # increment BUILD for every upload
   ```
3. Build:
   ```bash
   flutter build appbundle --build-name=1.2.0 --build-number=48
   ```
4. Commit: `chore(release): bump version to 1.2.0+48`
5. Tag after merge to `production`.

---

## 8. Rollback playbook

| Platform | Action |
|----------|--------|
| **Android** | Halt staged rollout; promote previous production release in Play Console **or** upload build from `release/previous` branch |
| **iOS** | Submit previous build from archived IPA / rebuild from `release/x.y.z` tag |
| **Web** | Redeploy artifact from git tag `v(previous)` |
| **Git** | `git checkout release/1.1.0` → hotfix if needed → new PATCH `1.1.1` |

---

## 9. Roles & responsibilities (draft)

| Role | Responsibility |
|------|----------------|
| **Tech lead** | Approve version number, branch cut, freeze exceptions |
| **Mobile** | `pubspec` bump, store submission, RC builds |
| **Web** | Tag-based deploy, version string in UI |
| **QA** | Test only against milestone `vX.Y.Z` / RC builds |
| **Product** | Release notes, rollout %, go/no-go |

---

## 10. Open decisions (for team review)

1. **Release cadence:** Fixed schedule (e.g. every 2 weeks) vs feature-driven?
2. **Web repo:** Same monorepo as Flutter or separate repo—how do we tag together?
3. **Environment branches:** Do we need `staging` branch or only `release/*` + `production`?
4. **Backend versioning:** Do APIs require `X-Client-Version` header per mobile/web build?
5. **Internal builds:** TestFlight / internal track naming (`1.2.0-rc.1+48`)?

---

## 11. Summary

- **Continue** mobile versioning via `pubspec.yaml` (`MAJOR.MINOR.PATCH+BUILD`).
- **Adopt the same `MAJOR.MINOR.PATCH`** for web starting next update.
- **Introduce `release/x.y.z` branches** and **git tags** per shipped version for rollback and consolidation.
- **Consolidate work** into version milestones; one RC branch → one tag → one coordinated ship (mobile + web).

---

## 12. Next steps

1. Review this draft in eng sync (Hemangi, Sanjeev, Bala, Rajanand).
2. Agree on cadence and open decisions (§10).
3. Pilot on **next release** (e.g. `1.1.0`): create `release/1.1.0`, tag `v1.1.0`, align web deploy.
4. Add CI check: fail PR to `production` if `pubspec` version was not bumped.

---

*Document version: 0.1 (draft) — feedback welcome.*
