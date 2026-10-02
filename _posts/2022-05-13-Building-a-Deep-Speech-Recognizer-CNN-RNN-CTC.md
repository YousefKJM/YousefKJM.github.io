---
title: "Building a Deep Speech Recognizer: Spectrograms, CNN+RNN, and CTC Loss"
excerpt: "An end-to-end ASR pipeline in Keras — audio to spectrogram to characters — and seven model architectures compared on real validation loss. Including the 'final' model that lost to a simpler one, and exactly why."
---

For an individual project I built an end-to-end **automatic speech recognition (ASR)** model: raw audio in, English text out, no hand-built phonetic dictionary. The code and all trained models are on [GitHub](https://github.com/YousefKJM/P3-DNN-Speech-Recognizer). (Speech recognition wasn't new to me — my team's *Mon9et* project used it to check Quran recitation — but this was building the acoustic model itself.)

## The pipeline

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 150" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="ASR pipeline: raw audio waveform converted to a spectrogram, fed to an acoustic model of convolution and recurrent layers, producing per-frame character probabilities, decoded by CTC into text">
  <defs><marker id="sr-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="35" width="105" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <polyline points="15,70 25,55 32,85 40,48 48,92 56,60 64,78 72,52 80,88 88,65 98,70" fill="none" stroke="var(--accent)" stroke-width="2"/>
    <text x="22" y="125" fill="var(--text)" font-weight="700">raw audio</text>
    <rect x="135" y="35" width="105" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <g fill="var(--accent)">
      <rect x="145" y="45" width="10" height="50" fill-opacity="0.3"/><rect x="157" y="45" width="10" height="50" fill-opacity="0.7"/>
      <rect x="169" y="45" width="10" height="50" fill-opacity="0.5"/><rect x="181" y="45" width="10" height="50" fill-opacity="0.9"/>
      <rect x="193" y="45" width="10" height="50" fill-opacity="0.4"/><rect x="205" y="45" width="10" height="50" fill-opacity="0.6"/>
      <rect x="217" y="45" width="12" height="50" fill-opacity="0.25"/>
    </g>
    <text x="146" y="125" fill="var(--text)" font-weight="700">spectrogram</text>
    <rect x="265" y="35" width="125" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="280" y="64" font-weight="700" fill="var(--accent)">acoustic model</text>
    <text x="280" y="84" fill="var(--text-muted)">Conv1D → Bi-GRU</text>
    <text x="280" y="125" fill="var(--text)" font-weight="700">the network</text>
    <rect x="415" y="35" width="105" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="428" y="64" fill="var(--text)">P(char) per</text>
    <text x="428" y="82" fill="var(--text)">time step</text>
    <text x="420" y="125" fill="var(--text)" font-weight="700">29 classes</text>
    <rect x="545" y="35" width="90" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="560" y="64" font-weight="700" fill="var(--text)">CTC</text>
    <text x="560" y="82" fill="var(--text-muted)">→ "hello"</text>
    <text x="560" y="125" fill="var(--text)" font-weight="700">decode</text>
    <line x1="110" y1="70" x2="131" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#sr-arr)"/>
    <line x1="240" y1="70" x2="261" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#sr-arr)"/>
    <line x1="390" y1="70" x2="411" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#sr-arr)"/>
    <line x1="520" y1="70" x2="541" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#sr-arr)"/>
  </g>
</svg>
</div>

## Step 1 — Turn audio into features

A neural network can't do much with 16,000 raw samples per second. Two standard representations:

| Feature | What it is | Shape per frame | Trade-off |
|---|---|---|---|
| **Spectrogram** | Energy at each frequency over short windows (FFT) | 161 values | Keeps all the information; bigger input |
| **MFCC** | Spectrogram compressed onto the mel scale (how humans hear pitch) | 13 values | Compact, removes some noise *and* some signal |

Normalize the features (zero mean, unit variance per dimension) or training converges painfully slowly. All the results below used spectrograms.

## Step 2 — Why CTC loss makes this possible at all

The training data says *"this 3-second clip is 'her father is…'"* — but not **which audio frame** each letter belongs to. Labelling that by hand would be absurd.

**Connectionist Temporal Classification (CTC)** solves it. The model outputs a character distribution for *every* frame, over 28 symbols plus a special **blank** (29 total). CTC sums the probability of every frame-level alignment that collapses to the right text:

```
frames:   h h _ e e _ l l _ _ l o o
collapse: merge repeats → h _ e _ l _ l o → remove blanks → "hello"
```

The blank is what lets "ll" survive: repeats only merge when no blank separates them. You get training on unaligned (audio, text) pairs — the key that makes end-to-end ASR work.

```python
from keras import backend as K

def ctc_lambda(args):
    y_pred, labels, input_len, label_len = args
    return K.ctc_batch_cost(labels, y_pred, input_len, label_len)
```

## Step 3 — Seven architectures, real results

All trained on the same data, measured by validation CTC loss (lower is better):

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Validation CTC loss, lower is better: simple RNN 759; RNN plus batch norm and time-distributed dense 166; CNN plus RNN 164; deep RNN 174; bidirectional RNN 205; CNN plus bidirectional RNN 136, the best; final custom model 206 after 40 epochs">
  <g style="font-size:12px;">
    <!-- scale: 800 loss -> 400px, x0=200 -->
    <line x1="200" y1="10" x2="200" y2="265" stroke="var(--border)"/>
    <text x="10" y="32" fill="var(--text)">0 Simple RNN</text>
    <rect x="200" y="18" width="380" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.45"/><text x="586" y="33" fill="var(--text)">759</text>
    <text x="10" y="68" fill="var(--text)">1 RNN + BN + TimeDist</text>
    <rect x="200" y="54" width="83" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="290" y="69" fill="var(--text)">166</text>
    <text x="10" y="104" fill="var(--text)">2 CNN + RNN</text>
    <rect x="200" y="90" width="82" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="289" y="105" fill="var(--text)">164</text>
    <text x="10" y="140" fill="var(--text)">3 Deep RNN (stacked)</text>
    <rect x="200" y="126" width="87" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="294" y="141" fill="var(--text)">174</text>
    <text x="10" y="176" fill="var(--text)">4 Bidirectional RNN</text>
    <rect x="200" y="162" width="102" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="309" y="177" fill="var(--text)">205</text>
    <text x="10" y="212" fill="var(--text)" font-weight="700">5 CNN + Bi-RNN</text>
    <rect x="200" y="198" width="68" height="20" rx="3" fill="var(--accent)"/><text x="275" y="213" font-weight="700" fill="var(--accent)">136 ← best</text>
    <text x="10" y="248" fill="var(--text)">Final custom (40 ep)</text>
    <rect x="200" y="234" width="103" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="310" y="249" fill="var(--text)">206</text>
    <text x="200" y="288" fill="var(--text-muted)">validation CTC loss · 20 epochs unless noted · lower is better</text>
  </g>
</svg>
</div>

| # | Architecture | Lesson |
|---|---|---|
| 0 | One GRU → softmax | Barely learns. A single recurrent layer can't map spectrograms to characters alone |
| 1 | GRU + **BatchNorm** + TimeDistributed Dense | **759 → 166.** Normalization alone was the biggest single jump |
| 2 | **Conv1D** in front of the GRU | Convolution extracts local acoustic patterns and shortens the sequence (stride 2). Faster *and* slightly better |
| 3 | Stacked GRUs | Train loss 153, val 174 — the gap says it started **overfitting** |
| 4 | Bidirectional GRU (no CNN) | Context from both directions, but alone it trained slower |
| 5 | **Conv1D + Bidirectional GRU** | **136** — local features from the CNN, two-way context from the Bi-GRU. Best by a clear margin |

## Step 4 — The final model, and why it lost

My "final" design went big — everything that helped, stacked deeper, with regularization everywhere:

```python
model_end = final_model(
    input_dim=161,
    cnn_layers=3, filters=350, kernel_size=11,
    conv_stride=1, dilation=4,                        # dilated convolutions, no downsampling
    cnn_implementation="BN-DR-AC", cnn_dropout=0.3,   # BatchNorm → Dropout → Activation
    recur_layers=3, recur_type="LSTM", reccur_units=200,
    reccur_droput=0.3, recurrent_dropout=0.1,         # dropout between AND inside recurrent steps
    reccur_merge_mode="sum",                          # bidirectional, directions summed
    fc_units=[400, 200, 100], fc_dropout=0.3,
)
```

After **40 epochs** — double everyone else's budget — it sat at a validation loss of **206, worse than model 5 at 20 epochs.** And train vs. validation loss were nearly equal (214 vs 206). That gap matters more than the number:

1. **No train/val gap means no overfitting to fight.** All that dropout (0.3 in the CNN, between LSTM layers, and in a three-layer dense head) was solving a problem the model didn't have — and it slows learning in a model this size.
2. **Stride 1 kept the full sequence length.** Models 2 and 5 used stride 2, halving the number of time steps the recurrent layers have to process. Three stacked bidirectional LSTMs over the full-length sequence is a much harder optimization problem.
3. **Depth isn't free.** Model 3 already showed stacking recurrent layers started overfitting at 200 units; going to three layers *plus* heavy dropout traded one problem for slow convergence.
4. **The better path:** start from model 5 (the proven winner), change **one** thing at a time, and add regularization only when training loss pulls away from validation loss.

The general rule: **diagnose before you regularize.** Train ≪ val → overfitting → add dropout or data. Train ≈ val, both high → the model is under-trained or under-powered → train longer, simplify the optimization, or add capacity. Piling regularization onto a model with no gap makes it worse.

## Step 5 — Decoding

At inference, the simplest decoder takes the most likely symbol per frame, merges repeats, and drops blanks (greedy CTC decoding):

```python
def greedy_ctc_decode(probs, index_map):
    best = np.argmax(probs, axis=-1)
    out, prev = [], None
    for idx in best:
        if idx != prev and idx != BLANK:
            out.append(index_map[idx])
        prev = idx
    return "".join(out)
```

Production systems add **beam search** plus a **language model** — "recognize speech" vs. "wreck a nice beach" sound almost identical; only a language model knows which one people actually say.

## What I'd take from this into any deep learning project

- **Normalize first** (BatchNorm took loss from 759 to 166 by itself).
- **CNN front end for signals** — audio, sensor data, anything with local patterns.
- **Bidirectional when you have the whole sequence** — offline transcription, not live streaming.
- **Read the train/val gap before touching regularization.**
- **Keep your best model, not your last one.** The best architecture here wasn't the one I called "final."
