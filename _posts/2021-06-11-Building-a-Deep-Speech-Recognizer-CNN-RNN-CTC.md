---
title: "Building a Deep Neural Network Speech Recognizer"
excerpt: "In this article I would like to present the end-to-end speech recognizer I built with Keras — turning audio into spectrograms, training seven CNN and RNN architectures with CTC loss, and what the real training curves showed, including why my 'final' model lost to a simpler one."
header:
  image: /images/posts/speech-recognizer/pipeline.png
---

<p align="center">
<img src="/images/posts/speech-recognizer/pipeline.png" alt="Speech recognition pipeline" style="margin-inline:auto;"/>
</p>

<h3><strong>Short introduction</strong></h3>
Speech recognition was not new to me: my team's project <em>Mon9et</em> used it to help users check their Quran recitation. But there we used existing speech-to-text tools. For this individual project I wanted to build the acoustic model myself — a deep neural network that takes raw audio and outputs English text, without any hand-made pronunciation dictionary. In this article I would like to walk you through the pipeline step by step, from audio features to CTC loss, and share the real training results of seven architectures. The code and trained models are on <a href="https://github.com/YousefKJM/P3-DNN-Speech-Recognizer" target="_blank" rel="noopener">GitHub</a>.

&nbsp;
<h3><strong>Step 1 — Turn audio into features</strong></h3>
The picture at the top shows the full pipeline: audio → features → acoustic model → text. Lets start from the audio itself. This is one training example from the dataset — a few seconds of someone reading a sentence:

<img src="/images/posts/speech-recognizer/audio-signal.png" alt="Raw audio signal" style="margin-inline:auto;" />

A neural network can't do much with 16,000 raw numbers per second, so we convert the audio into features. There are two common options. The first is the <strong>spectrogram</strong>, which shows the energy at each frequency over short time windows:

<img src="/images/posts/speech-recognizer/spectrogram.png" alt="Normalized spectrogram" style="margin-inline:auto;" />

The second is <strong>MFCC</strong> (mel-frequency cepstral coefficients), a compressed version of the spectrogram based on how humans hear pitch:

<img src="/images/posts/speech-recognizer/mfcc.png" alt="MFCC features" style="margin-inline:auto;" />

| Feature | Values per time step | Trade-off |
|---|---|---|
| Spectrogram | 161 | Keeps all the information, bigger input |
| MFCC | 13 | Compact, removes some noise but also some signal |

All the results in this article use spectrograms. Notice that the spectrogram is <strong>normalized</strong> (values around zero) — without that, training converges much more slowly.

&nbsp;
<h3><strong>Step 2 — CTC loss: the trick that makes it possible</strong></h3>
The training data tells us "this 3-second clip says <em>her father is a most remarkable person</em>", but it does not tell us which audio frame belongs to which letter. Labelling that by hand would be impossible.

<strong>Connectionist Temporal Classification (CTC)</strong> solves this problem. The model outputs a probability for each character at <strong>every</strong> time step — 28 characters plus a special <strong>blank</strong> symbol, 29 in total. CTC adds up the probabilities of all frame-level alignments that collapse into the correct text:

```
frames:   h h _ e e _ l l _ _ l o o
collapse: merge repeats → h _ e _ l _ l o → remove blanks → "hello"
```

The blank is what allows a double letter like "ll" to survive: repeated characters are merged only when there is no blank between them. In Keras, the loss is one function call:

```python
from keras import backend as K

def ctc_lambda(args):
    y_pred, labels, input_len, label_len = args
    return K.ctc_batch_cost(labels, y_pred, input_len, label_len)
```

&nbsp;
<h3><strong>Step 3 — Seven architectures</strong></h3>
In this section we will go through the models I trained, from the simplest to the most complex. For example, this is the CNN + RNN model, where a 1D convolution extracts local sound patterns before the recurrent layer:

<img src="/images/posts/speech-recognizer/cnn_rnn_model.png" alt="CNN + RNN model" style="margin-inline:auto;" />

And this is the bidirectional RNN, which reads the audio forward and backward:

<img src="/images/posts/speech-recognizer/bidirectional_rnn_model.png" alt="Bidirectional RNN model" width="520" style="margin-inline:auto;" />

These are the real training (left) and validation (right) CTC losses from my notebook, for 20 epochs (model 0 is left out because its loss stayed around 760 and would squash the chart):

<img src="/images/posts/speech-recognizer/training-curves.png" alt="Training and validation loss of models 1 to 5" style="margin-inline:auto;" />

And the final validation loss of every model, including the final one:

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

| # | Architecture | What it taught me |
|---|---|---|
| 0 | One GRU → softmax | It barely learns — loss stayed around 760 |
| 1 | GRU + **batch normalization** + TimeDistributed Dense | **759 → 166.** Normalization alone was the biggest single improvement |
| 2 | **Conv1D** + GRU | The convolution finds local patterns and halves the sequence length (stride 2). Faster and slightly better |
| 3 | Two stacked GRUs | Training loss 153 but validation 174 — the gap shows it started to **overfit** |
| 4 | Bidirectional GRU (no CNN) | Context from both directions, but on its own it trained slower |
| 5 | **Conv1D + bidirectional GRU** | **136** — local features from the CNN plus two-way context. The best model, clearly |

&nbsp;
<h3><strong>Step 4 — Why my final model lost</strong></h3>
For the final model I combined everything and went bigger, with regularization everywhere:

```python
model_end = final_model(
    input_dim=161,
    cnn_layers=3, filters=350, kernel_size=11,
    conv_stride=1, dilation=4,                        # dilated convolutions, no downsampling
    cnn_implementation="BN-DR-AC", cnn_dropout=0.3,   # BatchNorm -> Dropout -> Activation
    recur_layers=3, recur_type="LSTM", reccur_units=200,
    reccur_droput=0.3, recurrent_dropout=0.1,
    reccur_merge_mode="sum",                          # bidirectional, directions summed
    fc_units=[400, 200, 100], fc_dropout=0.3,
)
```

After <strong>40 epochs</strong> — double the training of the others — its validation loss was <strong>206, worse than model 5 after 20 epochs</strong>. More interesting is that the training and validation losses were almost equal (214 vs 206). When I looked at why, these were the reasons:

1. **No gap means no overfitting to fight.** All that dropout — in the CNN, between the LSTM layers and in a three-layer dense head — was solving a problem the model didn't have, and it slows learning down.
2. **Stride 1 kept the full sequence length.** Models 2 and 5 used stride 2, so the recurrent layers had half as many time steps. Three bidirectional LSTMs over the full sequence is a much harder optimization problem.
3. **Deeper is not automatically better.** Model 3 already showed that stacking recurrent layers started to overfit.

> **_NOTE:_**  The general rule: <strong>diagnose before you regularize.</strong> If training loss is much lower than validation loss, the model overfits → add dropout or more data. If both are similar and high, the model is under-trained or the optimization is too hard → train longer, simplify, or add capacity. Adding regularization to a model without a gap makes it worse.

&nbsp;
<h3><strong>Step 5 — From probabilities to text</strong></h3>
At prediction time, the simplest decoder takes the most likely symbol at each time step, merges repeats and removes blanks:

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

Real systems add <strong>beam search</strong> and a <strong>language model</strong> on top. "Recognize speech" and "wreck a nice beach" sound almost the same — only a language model knows which one people actually say.

&nbsp;
<h3><strong>Summary</strong></h3>
End-to-end speech recognition comes down to good features (normalized spectrograms), the right architecture (a CNN for local patterns plus a bidirectional RNN for context) and CTC loss, which makes it possible to train on audio without frame-level labels. The training curves also taught me that the best model is not always the last or the biggest one: model 5 beat my "final" model, and reading the train/validation gap explained why. The full notebook and models are on <a href="https://github.com/YousefKJM/P3-DNN-Speech-Recognizer" target="_blank" rel="noopener">GitHub</a>; the pipeline and architecture diagrams come from the project template provided by Udacity (MIT licence).
