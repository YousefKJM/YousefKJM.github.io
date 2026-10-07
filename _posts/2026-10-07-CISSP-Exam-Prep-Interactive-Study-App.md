---
title: "CISSP Exam Prep: Interactive Study App"
excerpt: "A fully interactive study tool for the ISC2 CISSP exam: 200 practice questions with study and timed exam modes, mind maps for all 8 domains, a 30-video MindMaps track, spaced-repetition flashcards, and manager-mindset scenario drills. Built while studying for the cert."
layout: post
tags: [CISSP, certification, GRC, security-leadership]
---
After the [MCFE study app](/MCFE-Exam-Prep-Interactive-Study-App/), I built the same kind of tool for the **ISC2 CISSP**. CISSP is a different animal. It's less about knowing where an artifact lives and more about choosing the answer a CISO would give the board. So the app trains judgment as much as recall: a 200-question bank with a timed exam mode, mind maps and study notes for all 8 domains, a guided video track, spaced-repetition flashcards, and scenario drills written from the manager's chair.

Use it below. It runs entirely in the browser, no account required.

<div style="position:relative;width:100%;height:90vh;margin:2rem 0;border-radius:var(--radius-m);overflow:hidden;border:1px solid var(--border);box-shadow:var(--shadow, 0 10px 30px rgba(0,0,0,0.3));">
  <iframe
    src="/CISSP-Exam-Prep/"
    style="width:100%;height:100%;border:none;display:block;"
    title="CISSP Exam Prep App"
    loading="lazy">
  </iframe>
</div>

<p style="text-align:center;font-size:0.85rem;color:var(--text-muted);margin-top:-1rem;">
  Having trouble loading? <a href="/CISSP-Exam-Prep/" target="_blank" rel="noopener">Open the app in a new tab →</a>
</p>

---

## What's inside

**Practice Exam (200 questions)**  
Original questions written to the 2024 exam outline, each with an explanation of why the best answer beats the distractors. Two modes:
- **Study:** see the answer after every question.
- **Exam:** timed at 1.2 minutes per question, and answers lock on submit, just like the real adaptive (CAT) exam.

Mixed sessions are weighted to the official domain percentages and serve questions you haven't seen, or got wrong, first.

**Study Guide & Mind Maps**  
Condensed key points and an interactive concept map for each of the 8 domains, from Security & Risk Management through Software Development Security.

**Video Lessons**  
All 30 videos from Destination Certification's [CISSP MindMaps (Updated for 2026)](https://www.youtube.com/playlist?list=PLZKdGEfEyJhLd-pJhAD7dNbJyUgpqI4pu) playlist, about 7 hours in total, mapped to their domains. Tick each one off as you watch, see how much runtime is left, and run a quick drill on that topic while it's fresh.

**Flashcards**  
134 terms, formulas and models with Leitner spaced repetition. Cards you know come back less often; misses come back tomorrow.

**Scenario Lab**  
16 judgment cases: the board wants zero risk, a vendor refuses audit rights, ransomware at 2 a.m., a pen test with no paperwork. Work out your answer, then compare it with the reasoning.

**Quick Reference & Progress**  
Instant search across every term and study note. Per-domain accuracy tells you exactly where to spend your next hour.

---

## CISSP at a glance

| | |
|---|---|
| **Format** | Computerized Adaptive Testing (English) |
| **Questions** | 100–150, including 25 unscored pretest items |
| **Time** | 3 hours |
| **Pass mark** | 700 out of 1000 (scaled) |
| **Domains** | 8, weighted 10–16% each (2024 outline) |
| **Experience** | 5 years paid work in 2+ domains (a degree or approved cert waives 1 year) |
| **Maintenance** | 120 CPEs over 3 years plus an annual fee |

CAT changes how you take the exam: you can't skip questions or go back. The exam can end at 100 questions whether you're clearly passing or clearly failing, so stopping early tells you nothing. Pace yourself at roughly 1.2 minutes per question and commit to each answer.

---

## Things most people get wrong

These are the patterns that trip up technical people, and all of them are drilled in the app:

- **Life safety comes first.** In a fire, evacuate, even mid-evidence-collection. Doors fail safe.
- **Think like a manager.** When one option is a hands-on fix and another addresses policy or risk, the governance answer usually wins.
- **FIRST means process order.** Get senior management support, set policy, assess risk, then pick controls. Don't jump to the tool.
- **Accountability can't be delegated or transferred.** Insurance moves the financial impact. Owners and senior management stay accountable.
- **Risk is never "ignored".** Acceptance is a formal, documented decision.
- **Containment comes before recovery.** Restoring from backup before you've scoped a ransomware incident means restoring into an active compromise.
- **Degaussing does nothing to SSDs.** Use crypto-erase or physical destruction (NIST SP 800-88).
- **Bell-LaPadula vs Biba:** no read up / no write down for confidentiality, the reverse for integrity.
- **Signing and encrypting use different keys:** you sign with your private key and encrypt with the recipient's public key.
- **RTO + WRT ≤ MTD.** Know which recovery metric drives what.

---

*Source code for the study app: [github.com/YousefKJM/CISSP-Exam-Prep](https://github.com/YousefKJM/CISSP-Exam-Prep). Video content belongs to Destination Certification; the app only links to it. The practice questions are original and aren't ISC2 material.*
