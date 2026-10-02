---
title: "The Software Engineering Field Kit: What Survives Contact With a Real Team"
excerpt: "Requirements that can be tested, a Git workflow that doesn't fight you, the testing pyramid, code review rules, and a definition of done — the parts of a software engineering degree that actually earn their keep once six people share one codebase."
---

My degree was in software engineering, and the capstone was InfoMagnet — a location-based media platform built by a team of six (Sails.js dashboard, native iOS and Android apps, MongoDB/Firebase). Most of the theory stayed in the textbook. These are the pieces that didn't.

## 1. Requirements: if you can't test it, it isn't one

| ❌ Vague | ✅ Testable |
|---|---|
| "The app should be fast" | "Feed loads in < 2 s on 4G for 50 items" |
| "Users can find nearby content" | "Content within 500 m of the user's GPS position appears, sorted by distance" |
| "The system is secure" | "Passwords stored with bcrypt; 5 failed logins lock the account for 15 min" |

Write each one as a **user story with acceptance criteria**:

```
As a  content creator
I want to pin a video to my current location
So that people walking past can discover it

Given I'm logged in and location is enabled
When I upload a video under 100 MB
Then it appears on the map at my position within 10 seconds
```

The "Given/When/Then" lines become your test cases directly.

## 2. Design: draw the boxes before writing the code

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 170" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Layered architecture: presentation layer calls service layer, which calls data access layer, which talks to the database; dependencies only point downward">
  <defs><marker id="se-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:13px;">
    <rect x="10" y="50" width="135" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="80" font-weight="700" fill="var(--text)">Presentation</text>
    <text x="24" y="100" fill="var(--text-muted)">UI, controllers</text>
    <rect x="170" y="50" width="135" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="184" y="80" font-weight="700" fill="var(--accent)">Service</text>
    <text x="184" y="100" fill="var(--text-muted)">business rules</text>
    <rect x="330" y="50" width="135" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="344" y="80" font-weight="700" fill="var(--text)">Data access</text>
    <text x="344" y="100" fill="var(--text-muted)">repositories</text>
    <rect x="490" y="50" width="140" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="504" y="80" font-weight="700" fill="var(--text)">Database</text>
    <text x="504" y="100" fill="var(--text-muted)">Mongo / SQL</text>
    <line x1="145" y1="85" x2="166" y2="85" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#se-arr)"/>
    <line x1="305" y1="85" x2="326" y2="85" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#se-arr)"/>
    <line x1="465" y1="85" x2="486" y2="85" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#se-arr)"/>
    <text x="10" y="150" fill="var(--text-muted)">Dependencies point one way. Swap the database or the UI without touching business rules.</text>
  </g>
</svg>
</div>

The rule that matters: **business logic never imports UI or database code directly.** It's what lets you test it without either, and what let our team build the dashboard and both mobile apps against one shared API.

## 3. Git workflow that doesn't fight you

```bash
git switch -c feature/geo-feed main      # one branch per story
# ...small commits...
git commit -m "feat(feed): sort content by distance from user"
git fetch origin && git rebase origin/main   # stay current, resolve conflicts early
git push -u origin feature/geo-feed          # open a pull request
```

| Rule | Why |
|---|---|
| `main` is always deployable | Anyone can ship at any time |
| Short-lived branches (≤ 2–3 days) | Merge conflicts grow with branch age |
| Conventional commits (`feat:`, `fix:`, `docs:`) | Readable history, automatic changelogs |
| Never commit secrets | `.gitignore` your `.env` on day one — history is forever |

## 4. The testing pyramid

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Testing pyramid: many fast unit tests at the base, fewer integration tests in the middle, a handful of slow end-to-end tests at the top">
  <g style="font-size:13px;">
    <polygon points="320,15 380,75 260,75" fill="var(--accent)" fill-opacity="0.35" stroke="var(--accent)"/>
    <polygon points="260,80 380,80 440,140 200,140" fill="var(--accent)" fill-opacity="0.55" stroke="var(--accent)"/>
    <polygon points="200,145 440,145 500,205 140,205" fill="var(--accent)" fill-opacity="0.8" stroke="var(--accent)"/>
    <text x="300" y="62" font-weight="700" fill="var(--text)">E2E</text>
    <text x="278" y="116" font-weight="700" fill="var(--text)">Integration</text>
    <text x="300" y="181" font-weight="700" fill="var(--accent-contrast)">Unit</text>
    <text x="400" y="50" fill="var(--text-muted)">~10%  slow, brittle, high confidence</text>
    <text x="455" y="112" fill="var(--text-muted)">~20%  API + DB together</text>
    <text x="515" y="180" fill="var(--text-muted)">~70%  ms each</text>
  </g>
</svg>
</div>

Invert the pyramid — mostly UI tests, few unit tests — and your suite becomes slow, flaky, and ignored. A test that nobody runs protects nothing.

```python
# A good unit test: one behaviour, no network, no database, readable name
def test_nearby_content_excludes_items_beyond_radius():
    user = (26.30, 50.15)
    items = [Item("near", 26.301, 50.151), Item("far", 26.40, 50.30)]
    assert [i.name for i in nearby(items, user, radius_m=500)] == ["near"]
```

## 5. Code review: rules for both sides

**Author**
- Keep PRs under ~400 lines. Review quality collapses above that.
- Write the PR description: *what* changed, *why*, *how you tested it*.
- Review your own diff first. You'll catch a third of the comments yourself.

**Reviewer**
- Correctness and design first; style is the linter's job, not yours.
- Ask questions instead of issuing orders: "What happens if `location` is null here?"
- Approve when it's better than `main`, not when it's perfect.

## 6. Definition of done

A story isn't done when the code compiles. It's done when:

- [ ] Acceptance criteria pass
- [ ] Unit tests added; full suite green in CI
- [ ] Reviewed and approved by at least one other person
- [ ] No new linter or security-scanner warnings
- [ ] Docs/README updated if behaviour changed
- [ ] Deployed to staging and smoke-tested

Agree on this list as a team in week one. Most "it's done but…" arguments are really disagreements about this list.

## The short version

Testable requirements, one-way dependencies, short branches, a pyramid-shaped test suite, small PRs, and a written definition of done. None of it is glamorous. All of it compounds.
