---
title: "Software Engineering Practices That Survive a Real Team"
excerpt: "Six people, one repository, one semester. The handful of engineering habits that kept our senior project shippable — from requirements you can test to a definition of done nobody can argue with."
tags: [Software, engineering, testing, Git, architecture]
---
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

Software Engineering at KFUPM gave me plenty of theory. Our senior project, InfoMagnet, gave me the reality check. It was a location-aware media platform built by six of us: a Sails.js dashboard, native iOS and Android apps, and a MongoDB/Firebase backend. With six people pushing to the same repository every day, you find out very quickly which practices earn their place and which ones only look good in a slide.

What follows is the short list that survived, in the order a feature actually travels: from the first requirement to the moment we could honestly call it "done".

## Requirements: if you can't test it, it isn't one
Requirements come first, because everything else depends on them. The most common problem is a requirement that sounds good but cannot be tested:

| ❌ Vague | ✅ Testable |
|---|---|
| "The app should be fast" | "Feed loads in less than 2 seconds on 4G for 50 items" |
| "Users can find nearby content" | "Content within 500 m of the user's GPS position appears, sorted by distance" |
| "The system is secure" | "Passwords stored with bcrypt; 5 failed logins lock the account for 15 minutes" |

We wrote every feature as a <strong>user story with acceptance criteria</strong>:

```
As a  content creator
I want to pin a video to my current location
So that people walking past can discover it

Given I'm logged in and location is enabled
When I upload a video under 100 MB
Then it appears on the map at my position within 10 seconds
```

Notice that the "Given / When / Then" lines are already test cases. You don't have to invent tests later — they are written together with the requirement.

## Design: draw the boxes before writing the code
The diagram at the top of this article is the one rule of architecture I always follow: <strong>layers, and dependencies only point one way</strong>. The presentation layer calls the service layer, the service layer calls the data layer, and never the other way around.

Why does it matter? Because business logic that doesn't import UI or database code can be tested without either of them. It is also what allowed our team to build the web dashboard and both mobile apps against one shared API, without copying business rules into three places.

## Git workflow that doesn't fight you
Here is the simplest workflow I know that still keeps `main` safe. One branch per story, small commits, and a pull request at the end:

```bash
git switch -c feature/geo-feed main          # one branch per story
# ...small commits...
git commit -m "feat(feed): sort content by distance from user"
git fetch origin && git rebase origin/main   # stay current, resolve conflicts early
git push -u origin feature/geo-feed          # then open a pull request
```

These are the rules we agreed on:

| Rule | Why |
|---|---|
| `main` is always deployable | Anyone can ship at any time |
| Short-lived branches (2–3 days max) | Merge conflicts grow with the age of the branch |
| Conventional commits (`feat:`, `fix:`, `docs:`) | Readable history and automatic changelogs |
| Never commit secrets | Add `.env` to `.gitignore` on day one — Git history is forever |

> **Tip:** If you are using Azure DevOps, you can enforce some of these rules with branch policies, like a minimum number of reviewers before a pull request can be completed. I showed how to set this up in my [Azure DevOps article](/Microsoft-Azure-DevOps-for-ASP-.NET-Core-Web-apps/).

## The testing pyramid
Once code is merged often, tests are the only thing protecting `main`. The question is which tests to write. This is the shape that works:

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

Most tests should be fast unit tests at the bottom, some integration tests in the middle (API and database together), and only a few slow end-to-end tests at the top. If you invert it — mostly UI tests and few unit tests — the test suite becomes slow and flaky, people stop running it, and a test that nobody runs protects nothing.

A good unit test checks one behaviour, needs no network and no database, and has a name that explains itself:

```python
def test_nearby_content_excludes_items_beyond_radius():
    user = (26.30, 50.15)
    items = [Item("near", 26.301, 50.151), Item("far", 26.40, 50.30)]
    assert [i.name for i in nearby(items, user, radius_m=500)] == ["near"]
```

## Code review: rules for both sides
Code review is where a team either learns together or argues together. These rules helped us stay on the first side.

<strong>For the author:</strong>

1. Keep pull requests under ~400 lines. Review quality drops a lot above that.
2. Write a description: <em>what</em> changed, <em>why</em>, and <em>how you tested it</em>.
3. Review your own diff first — you will catch around a third of the comments yourself.

<strong>For the reviewer:</strong>

1. Focus on correctness and design first. Style is the job of the linter, not yours.
2. Ask questions instead of giving orders: "What happens if `location` is null here?"
3. Approve when the change makes `main` better, not when it is perfect.

## Definition of done
The last step is agreeing on what "done" means. A story is not done when the code compiles. For us it was done when:

- [ ] Acceptance criteria pass
- [ ] Unit tests are added and the full suite is green in CI
- [ ] At least one other person reviewed and approved it
- [ ] No new linter or security scanner warnings
- [ ] The README or docs are updated if the behaviour changed
- [ ] It is deployed to staging and smoke-tested

Agree on this list in the first week. Most of the "it's done, but…" discussions in a team are really disagreements about this list.

## The habits that stuck

None of these practices is complicated: requirements you can test, dependencies that point one way, short-lived branches, a test suite shaped like a pyramid, small pull requests and a written definition of done. The power comes from doing all of them, every time, as a team. If you want to go further, the <a href="https://www.conventionalcommits.org/" target="_blank" rel="noopener">Conventional Commits</a> specification and Martin Fowler's <a href="https://martinfowler.com/articles/practical-test-pyramid.html" target="_blank" rel="noopener">practical test pyramid</a> are where I would continue.
