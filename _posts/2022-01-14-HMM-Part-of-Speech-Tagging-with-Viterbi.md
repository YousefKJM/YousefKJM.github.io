---
title: "Part-of-Speech Tagging with a Hidden Markov Model, Step by Step"
excerpt: "How a 1960s-era statistical model still tags 'count' correctly as a noun or a verb from context. Counting your way to an HMM, the Viterbi algorithm on a trellis you can follow by hand, and about forty lines of Python that implement both."
---

Before transformers, before word embeddings, a **Hidden Markov Model** was the standard way to tag every word in a sentence with its grammatical role. I built one as an individual NLP project. It's still the best introduction there is to sequence modelling — every idea in it (states, transitions, dynamic programming over a sequence) shows up again in RNNs, CRFs, and speech recognition.

## The problem

The word **"count"** is a noun in *"the count was wrong"* and a verb in *"count the votes."* A dictionary can't decide. Context can.

## The model: two tables, both just counts

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 190" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Hidden Markov Model: hidden tag states DET, NOUN, VERB connected left to right by transition probabilities; each emits an observed word below it through an emission probability">
  <defs><marker id="hm-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:13px;">
    <text x="10" y="54" fill="var(--text-muted)">hidden</text>
    <text x="10" y="70" fill="var(--text-muted)">tags</text>
    <circle cx="160" cy="60" r="32" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/><text x="143" y="65" font-weight="700" fill="var(--accent)">DET</text>
    <circle cx="340" cy="60" r="32" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/><text x="315" y="65" font-weight="700" fill="var(--accent)">NOUN</text>
    <circle cx="520" cy="60" r="32" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/><text x="499" y="65" font-weight="700" fill="var(--accent)">VERB</text>
    <line x1="192" y1="60" x2="304" y2="60" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#hm-arr)"/>
    <line x1="372" y1="60" x2="484" y2="60" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#hm-arr)"/>
    <text x="205" y="50" fill="var(--text-muted)">P(NOUN | DET)</text>
    <text x="385" y="50" fill="var(--text-muted)">P(VERB | NOUN)</text>
    <text x="10" y="164" fill="var(--text-muted)">words</text>
    <rect x="125" y="140" width="70" height="34" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="145" y="162" fill="var(--text)">the</text>
    <rect x="305" y="140" width="70" height="34" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="320" y="162" fill="var(--text)">count</text>
    <rect x="485" y="140" width="70" height="34" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="506" y="162" fill="var(--text)">was</text>
    <line x1="160" y1="92" x2="160" y2="136" stroke="var(--border)" stroke-width="2" marker-end="url(#hm-arr)"/>
    <line x1="340" y1="92" x2="340" y2="136" stroke="var(--border)" stroke-width="2" marker-end="url(#hm-arr)"/>
    <line x1="520" y1="92" x2="520" y2="136" stroke="var(--border)" stroke-width="2" marker-end="url(#hm-arr)"/>
    <text x="350" y="120" fill="var(--text-muted)">P(count | NOUN)</text>
  </g>
</svg>
</div>

| Table | Question it answers | Estimated from a tagged corpus as |
|---|---|---|
| **Transition** `P(tagᵢ │ tagᵢ₋₁)` | How likely is a NOUN after a DET? | `count(DET→NOUN) / count(DET)` |
| **Emission** `P(word │ tag)` | If the tag is NOUN, how likely is the word "count"? | `count(NOUN, "count") / count(NOUN)` |
| **Start** `P(tag₁)` | How likely is a sentence to start with DET? | `count(sentences starting DET) / count(sentences)` |

That's the entire training step: **counting** over a tagged corpus like Brown. No gradient descent.

## Step 1 — Train (count and normalize)

```python
from collections import Counter, defaultdict

def train(tagged_sentences):
    start, trans, emit, tag_count = Counter(), defaultdict(Counter), defaultdict(Counter), Counter()
    for sent in tagged_sentences:                       # sent = [("the","DET"), ("count","NOUN"), ...]
        tags = [t for _, t in sent]
        start[tags[0]] += 1
        for (w, t) in sent:
            emit[t][w.lower()] += 1
            tag_count[t] += 1
        for prev, cur in zip(tags, tags[1:]):
            trans[prev][cur] += 1
    return start, trans, emit, tag_count
```

## Step 2 — Smooth, or one unseen word kills everything

A word never seen with a tag gets probability **0**, and multiplying by 0 zeroes out every path through it. Add-one (Laplace) smoothing fixes it:

```python
import math

def log_p(counter, key, total, vocab_size):
    return math.log((counter[key] + 1) / (total + vocab_size))   # never log(0)
```

Work in **log space** throughout: multiplying 20 small probabilities underflows to 0.0 in floating point; adding their logs doesn't.

## Step 3 — Decode with Viterbi

Brute force is hopeless: 12 tags over a 20-word sentence is 12²⁰ possible tag sequences. Viterbi uses dynamic programming: at each word, for each tag, keep **only the best path that ends in that tag.**

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Viterbi trellis for the sentence count the votes: columns are words, rows are tags; the highlighted best path is VERB, DET, NOUN">
  <g style="font-size:13px;">
    <text x="150" y="22" font-weight="700" fill="var(--text)">"count"</text>
    <text x="330" y="22" font-weight="700" fill="var(--text)">"the"</text>
    <text x="500" y="22" font-weight="700" fill="var(--text)">"votes"</text>
    <text x="10" y="64" fill="var(--text-muted)">NOUN</text>
    <text x="10" y="124" fill="var(--text-muted)">VERB</text>
    <text x="10" y="184" fill="var(--text-muted)">DET</text>
    <g stroke="var(--border)" stroke-width="1.5">
      <line x1="175" y1="60" x2="340" y2="180"/><line x1="175" y1="180" x2="340" y2="180"/>
      <line x1="340" y1="180" x2="515" y2="120"/>
    </g>
    <g stroke="var(--accent)" stroke-width="4">
      <line x1="175" y1="120" x2="340" y2="180"/>
      <line x1="340" y1="180" x2="515" y2="60"/>
    </g>
    <circle cx="175" cy="60" r="16" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <circle cx="175" cy="120" r="16" fill="var(--accent)"/>
    <circle cx="175" cy="180" r="16" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <circle cx="340" cy="60" r="16" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <circle cx="340" cy="120" r="16" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <circle cx="340" cy="180" r="16" fill="var(--accent)"/>
    <circle cx="515" cy="60" r="16" fill="var(--accent)"/>
    <circle cx="515" cy="120" r="16" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <circle cx="515" cy="180" r="16" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="10" y="220" fill="var(--text-muted)">Best path: VERB → DET → NOUN — "count" before "the" reads as a verb.</text>
  </g>
</svg>
</div>

```python
def viterbi(words, tags, start, trans, emit, tag_count, V):
    words = [w.lower() for w in words]
    n_sent = sum(start.values())
    # best[i][t] = (log-prob of best path ending in tag t at word i, backpointer)
    best = [{t: (log_p(start, t, n_sent, len(tags)) +
                 log_p(emit[t], words[0], tag_count[t], V), None) for t in tags}]
    for i in range(1, len(words)):
        col = {}
        for t in tags:
            e = log_p(emit[t], words[i], tag_count[t], V)
            prev_t, score = max(
                ((p, best[i-1][p][0] + log_p(trans[p], t, tag_count[p], len(tags))) for p in tags),
                key=lambda x: x[1])
            col[t] = (score + e, prev_t)
        best.append(col)
    # backtrack from the best final tag
    t = max(best[-1], key=lambda k: best[-1][k][0])
    path = [t]
    for i in range(len(words) - 1, 0, -1):
        t = best[i][t][1]
        path.append(t)
    return list(reversed(path))
```

Cost: `O(n × T²)` — linear in sentence length. For 20 words and 12 tags that's under 3,000 steps instead of 12²⁰.

## Step 4 — Evaluate honestly

- **Split by sentence** (e.g. 80/20). Never evaluate on sentences the model counted.
- Report accuracy on **all words and on unknown words separately** — the overall number hides how badly you handle vocabulary you've never seen.
- Baseline first: "tag each word with its most frequent tag" already scores in the low 90s on Brown. Your HMM has to beat that to mean anything.

## Where it breaks, and what replaced it

| Limitation | Why | What fixed it |
|---|---|---|
| Unknown words | Emission prob is just a smoothing constant | Suffix features (`-ing`, `-ly`) → CRFs |
| Only looks one tag back | Bigram Markov assumption | Trigram HMMs, then BiLSTMs |
| Words are atomic symbols | "run"/"running" share nothing | Word embeddings |

## Why it's worth knowing in 2022

The same three moves — **hidden states, transition scores, dynamic-programming decode** — power CTC decoding in [speech recognition](/Building-a-Deep-Speech-Recognizer-CNN-RNN-CTC/) and beam search in [machine translation](/Neural-Machine-Translation-with-RNNs/). Learn Viterbi once and you'll recognize it everywhere.
