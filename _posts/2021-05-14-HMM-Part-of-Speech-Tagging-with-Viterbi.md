---
title: "Part-of-Speech Tagging with a Hidden Markov Model and Viterbi"
excerpt: "Is \"count\" a noun or a verb? A Hidden Markov Model trained by counting and decoded with Viterbi — tested on the Brown corpus, including the smoothing mistake that made it lose to a one-line baseline."
tags: [AI, NLP, HMM, Viterbi, Python]
---
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

<strong>"Count"</strong> is a noun in <em>"the count was wrong"</em> and a verb in <em>"count the votes"</em>. A dictionary can't tell which; only the context can. Choosing the right grammatical role for every word — part-of-speech (POS) tagging — sits underneath speech synthesis, search and plenty of other NLP tasks.

For an individual NLP project I built a POS tagger on a <strong>Hidden Markov Model (HMM)</strong> and tested it on the Brown corpus. The results were real, and so was the mistake I made along the way — one that's very easy to repeat.

## The model
The diagram at the top of this article shows the idea. The tags (DET, NOUN, VERB, …) are <strong>hidden states</strong> — we can't see them. What we see are the words. The model has two tables, and both of them are just counts from a tagged corpus:

| Table | Question it answers | Estimated as |
|---|---|---|
| **Transition** `P(tagᵢ │ tagᵢ₋₁)` | How likely is a NOUN after a DET? | `count(DET→NOUN) / count(DET)` |
| **Emission** `P(word │ tag)` | If the tag is NOUN, how likely is the word "count"? | `count(NOUN, "count") / count(NOUN)` |
| **Start** `P(tag₁)` | How likely does a sentence start with DET? | `count(sentences starting with DET) / count(sentences)` |

For the data I used the <strong>Brown corpus</strong> from NLTK with the universal tagset (12 tags). It has 57,340 tagged sentences, which I split 80% for training and 20% for testing.

## Step 1 — Train by counting
Training an HMM means counting. There is no gradient descent:

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

## Step 2 — Decode with Viterbi
Now we need to find the best tag sequence for a new sentence. Trying every combination is impossible: 12 tags over a 20-word sentence is 12²⁰ sequences. The <strong>Viterbi algorithm</strong> uses dynamic programming instead: for every word and every tag, it keeps <strong>only the best path that ends in that tag</strong>, then follows the back-pointers at the end:

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
import math

def viterbi(words, tags, start, trans, tag_count, emit_logp):
    words = [w.lower() for w in words]
    n = sum(start.values())
    tr = lambda p, t: math.log((trans[p][t] + 1) / (tag_count[p] + len(tags)))
    # best[i][t] = (log-prob of the best path ending in tag t at word i, back-pointer)
    best = [{t: (math.log((start[t] + 1) / (n + len(tags))) + emit_logp(t, words[0]), None) for t in tags}]
    for i in range(1, len(words)):
        col = {}
        for t in tags:
            p, score = max(((p, best[i-1][p][0] + tr(p, t)) for p in tags), key=lambda x: x[1])
            col[t] = (score + emit_logp(t, words[i]), p)
        best.append(col)
    t = max(best[-1], key=lambda k: best[-1][k][0])   # follow the back-pointers
    path = [t]
    for i in range(len(words) - 1, 0, -1):
        t = best[i][t][1]
        path.append(t)
    return path[::-1]
```

This runs in `O(n × T²)`: for 20 words and 12 tags, that is under 3,000 steps instead of 12²⁰.

> **Numerical trap:** Always work with <strong>log probabilities</strong>. Multiplying 20 small probabilities becomes 0.0 in floating point (underflow). Adding their logs doesn't.

## Step 3 — Emission probabilities and the mistake I made
A word that never appeared with a tag in training gets probability 0, and one zero kills every path through it. The textbook fix is <strong>add-one (Laplace) smoothing</strong>: add 1 to every count. So the obvious first version uses it for emissions too:

```python
def laplace_emit(emit, tag_count, V):
    return lambda t, w: math.log((emit[t][w] + 1) / (tag_count[t] + V))   # V = vocabulary size
```

Then I compared it with the simplest possible baseline — tag every word with the tag it had most often in training (and NOUN for unknown words). These are the real results on the 232,177 test words:

| Model | Accuracy | Unknown words |
|---|---|---|
| Most-frequent-tag baseline | 94.61% | 60.24% |
| HMM + Viterbi, Laplace emissions | 93.96% ❌ | 45.39% |

The HMM <strong>lost to the baseline</strong>. The reason is the unknown words (2.2% of the test words). The vocabulary has 45,153 words, so adding 1 for every word gives each unseen word almost the same tiny probability under every tag. The model has no idea which tag an unknown word probably is.

The fix is to handle two different cases separately:

1. A word we know, but never saw with this tag → a very small probability.
2. A word we have never seen at all → estimate how often each tag produces <strong>new</strong> words. A good estimate is the share of words that appeared only once with that tag (called <em>hapax</em> words). Open classes like NOUN have many of them; closed classes like DET almost none.

```python
def make_emit_logp(emit, tag_count, vocab, k=0.001):
    hapax = Counter(t for t in emit for w, c in emit[t].items() if c == 1)
    def emit_logp(t, w):
        c = emit[t][w]
        if c:          return math.log(c / tag_count[t])          # seen with this tag
        if w in vocab: return math.log(1e-12)                     # known word, never with this tag
        return math.log((hapax[t] + k) / tag_count[t])            # unknown word: how often t makes new words
    return emit_logp
```

And the result:

| Model | Accuracy | Unknown words |
|---|---|---|
| Most-frequent-tag baseline | 94.61% | 60.24% |
| HMM + Viterbi, Laplace emissions | 93.96% | 45.39% |
| HMM + Viterbi, hapax unknown-word model | **96.43%** ✅ | **62.69%** |

And of course the sentences from the introduction:

```
count the votes .      →  count/VERB  the/DET  votes/NOUN  ./.
the count was wrong .  →  the/DET  count/NOUN  was/VERB  wrong/ADJ  ./.
```

## Step 4 — Evaluate honestly
This experiment is a good reminder of three rules worth following for any model:

1. **Always compare with a simple baseline first.** Without the baseline, 93.96% would have looked like a good result.
2. **Report unknown words separately.** The overall number hides how badly a model handles words it has never seen.
3. **Split by sentence**, and never evaluate on sentences the model was trained on.

## The real lesson

An HMM is trained by counting and decoded with Viterbi, and it can still tell "count the votes" from "the count was wrong". But the biggest lesson wasn't the algorithm — it was the evaluation. Textbook smoothing made the model worse than a one-line baseline, and only a proper unknown-word model fixed it. Hidden states, transition scores and dynamic programming come back again in speech recognition and machine translation, my next two projects. To experiment yourself, the <a href="https://www.nltk.org/book/ch05.html" target="_blank" rel="noopener">NLTK book chapter on tagging</a> is a great start.
