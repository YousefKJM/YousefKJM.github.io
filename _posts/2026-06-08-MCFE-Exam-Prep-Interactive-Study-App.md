---
title: "MCFE Exam Prep: Interactive Study App"
excerpt: "A fully interactive study tool for the Magnet Certified Forensics Examiner (MCFE) exam — 100 practice questions, module summaries, mind maps, DFIR lab reference, community tips, and a pre-exam checklist. Built while studying for the cert."
layout: post
---

I built this while studying for the **Magnet Certified Forensics Examiner (MCFE)** certification. Rather than a static notes page, I put everything into an interactive tool: a 100-question practice bank, collapsible module summaries, mind maps for all 12 AX200 modules, a searchable DFIR lab reference, community intel from practitioners who've sat the exam, and a pre-exam checklist.

Use it below — it runs entirely in the browser, no account required.

<div style="position:relative;width:100%;height:90vh;margin:2rem 0;border-radius:var(--radius-m);overflow:hidden;border:1px solid var(--border);box-shadow:var(--shadow, 0 10px 30px rgba(0,0,0,0.3));">
  <iframe
    src="/MCFE-Exam-Prep/"
    style="width:100%;height:100%;border:none;display:block;"
    title="MCFE Exam Prep App"
    loading="lazy">
  </iframe>
</div>

<p style="text-align:center;font-size:0.85rem;color:var(--text-muted);margin-top:-1rem;">
  Having trouble loading? <a href="/MCFE-Exam-Prep/" target="_blank" rel="noopener">Open the app in a new tab →</a>
</p>

---

## What's inside

**Practice Quiz (100 questions)**  
Full multiple-choice bank covering all 12 AX200 modules. Choose 10, 20, 30, 50, 75, or all 100 questions. Detailed explanations on every answer. Filter by module or go mixed.

**Module Summaries & Mind Maps**  
Collapsible bullet-point summaries and visual mind maps for each module — from Installation & Overview through Reporting.

**DFIR Lab Reference**  
Searchable quick-reference covering key artifacts, registry paths, file system paths, playbooks, and quick-reference tables. Includes an Anti-Forensics Detection category.

**Community Intelligence**  
Real insights from practitioners who've sat the exam — sourced from r/computerforensics and published course reviews. Includes the breakdown of what the exam actually looks like.

**Pre-Exam Checklist**  
Step-by-step checklist for the day of the exam, including the critical items most candidates miss (build Connections and Timeline *before* starting the timer).

**Calm Mindset**  
Mindset cards for exam-day nerves, plus breathing/focus exercises.

---

## MCFE at a glance

| | |
|---|---|
| **Questions** | 75 multiple choice / true-false |
| **Time** | 120 minutes |
| **Pass mark** | 80% or higher |
| **Valid** | 2 years |
| **On failure** | Fail once → immediate retry · Fail twice → 60-day lockout |
| **Qualifying courses** | AX200, CY200, BCERT (NCFI), approved custom courses |

The exam is open book and open case — you can have the PDF manual and the Lewis Case MFDB open during the test. The constraint is time: 120 minutes for 75 questions, with roughly half of them requiring you to navigate the actual evidence file to answer. Processing everything and building Connections and Timeline before you start the clock is not optional.

---

## Things most people get wrong

These are the exam traps that show up consistently — all covered in the practice quiz:

- **Filters bar turns YELLOW when active** (not red, not orange — yellow)
- **Mobile View: apps are NOT in their original device order**
- **Email Explorer Participants filter is CASE SENSITIVE**
- **Firefox cache = AppData\Local (not Roaming)** · bookmarks (places.sqlite) = Roaming
- **Chrome content and metadata are stored as SEPARATE components**
- **Rebuilt Desktops = Windows 10 ONLY** — not 7, 8, or 11
- **Prefetch max: XP=126 · Vista/7/8=129 · Win10/11=1024** — know all three
- **Hit stack tagging applies to ALL copies** across all evidence sources
- **Build 1803 = Windows Timeline introduced** — build number determines artifact presence
- **Cloud OneDrive Files ≠ local OneDrive** — cloud version may have files not stored locally and shows Shared With info

---

*Source code for the study app: [github.com/YousefKJM/MCFE-Exam-Prep](https://github.com/YousefKJM/MCFE-Exam-Prep)*
