---
title: "Neural Machine Translation with RNNs: Five Architectures, One Surprising Winner"
excerpt: "English to French with Keras — a simple RNN, embeddings, a bidirectional RNN, an encoder-decoder, and a combined model, trained on the same 137k sentence pairs. The real validation numbers, and why the 'most advanced' model didn't win."
---

For an individual project I built an English→French translator, comparing five recurrent architectures on the same data. The code is on [GitHub](https://github.com/YousefKJM/P2-Machine-Translation). The results taught me more than the architecture diagrams did.

## How machine translation got here

| Era | Approach | Core idea | Weakness |
|---|---|---|---|
| 1950s–80s | **Rule-based** | Linguists hand-write grammar and dictionaries | Doesn't scale; every exception is a new rule |
| 1990s–2014 | **Statistical (SMT)** | Learn phrase-translation probabilities from parallel text | Translates phrase by phrase; clunky word order |
| — | **Example-based** | Translate by analogy to stored sentence pairs | Coverage limited to what's been seen |
| 2014+ | **Neural (NMT)** | One network reads the whole sentence, writes the whole translation | Data-hungry; long sentences hard without attention |

## The data and preprocessing

137,860 English–French sentence pairs from a deliberately small vocabulary:

```
new jersey is sometimes quiet during autumn , and it is snowy in april .
new jersey est parfois calme pendant l' automne , et il est neigeux en avril .
```

Three preprocessing steps, every NMT pipeline:

```python
from keras.preprocessing.text import Tokenizer
from keras.preprocessing.sequence import pad_sequences

def tokenize(sentences):
    tk = Tokenizer()
    tk.fit_on_texts(sentences)                    # word → integer id
    return tk.texts_to_sequences(sentences), tk

def pad(seqs, length=None):
    return pad_sequences(seqs, maxlen=length, padding="post")   # equal length, zeros at the end

x, x_tk = tokenize(english);  x = pad(x)
y, y_tk = tokenize(french);   y = pad(y)
y = y.reshape(*y.shape, 1)    # sparse_categorical_crossentropy wants a trailing dim
```

## The five architectures

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 310" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Five model architectures as layer stacks: simple RNN; embedding plus RNN; bidirectional RNN; encoder-decoder with a repeat vector bottleneck; final model combining embedding, bidirectional encoder, bottleneck and bidirectional decoder">
  <g style="font-size:11px;">
    <text x="10" y="18" font-weight="700" fill="var(--text)">1 Simple RNN</text>
    <text x="138" y="18" font-weight="700" fill="var(--text)">2 Embedding</text>
    <text x="266" y="18" font-weight="700" fill="var(--text)">3 Bidirectional</text>
    <text x="394" y="18" font-weight="700" fill="var(--text)">4 Enc-Dec</text>
    <text x="522" y="18" font-weight="700" fill="var(--accent)">5 Final</text>
    <!-- col1 -->
    <rect x="10" y="30" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="20" y="51" fill="var(--text)">GRU (seq)</text>
    <rect x="10" y="70" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="20" y="91" fill="var(--text)">Dense softmax</text>
    <!-- col2 -->
    <rect x="138" y="30" width="110" height="34" rx="5" fill="var(--accent)" fill-opacity="0.25" stroke="var(--accent)"/><text x="148" y="51" fill="var(--text)">Embedding</text>
    <rect x="138" y="70" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="148" y="91" fill="var(--text)">GRU (seq)</text>
    <rect x="138" y="110" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="148" y="131" fill="var(--text)">Dense softmax</text>
    <!-- col3 -->
    <rect x="266" y="30" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="276" y="51" fill="var(--text)">Bi-GRU (seq)</text>
    <rect x="266" y="70" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="276" y="91" fill="var(--text)">Dense softmax</text>
    <!-- col4 -->
    <rect x="394" y="30" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="404" y="51" fill="var(--text)">GRU encoder</text>
    <rect x="394" y="70" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="404" y="91" fill="var(--text)">Dense 512</text>
    <rect x="394" y="110" width="110" height="34" rx="5" fill="var(--accent)" fill-opacity="0.25" stroke="var(--accent)"/><text x="404" y="131" fill="var(--text)">RepeatVector</text>
    <rect x="394" y="150" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="404" y="171" fill="var(--text)">GRU decoder</text>
    <rect x="394" y="190" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="404" y="211" fill="var(--text)">Dense softmax</text>
    <!-- col5 -->
    <rect x="522" y="30" width="110" height="34" rx="5" fill="var(--accent)" fill-opacity="0.25" stroke="var(--accent)"/><text x="532" y="51" fill="var(--text)">Embedding</text>
    <rect x="522" y="70" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="532" y="91" fill="var(--text)">Bi-GRU encoder</text>
    <rect x="522" y="110" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="532" y="131" fill="var(--text)">Dense 512</text>
    <rect x="522" y="150" width="110" height="34" rx="5" fill="var(--accent)" fill-opacity="0.25" stroke="var(--accent)"/><text x="532" y="171" fill="var(--text)">RepeatVector</text>
    <rect x="522" y="190" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="532" y="211" fill="var(--text)">Bi-GRU decoder</text>
    <rect x="522" y="230" width="110" height="34" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="532" y="251" fill="var(--text)">Dense softmax</text>
    <text x="10" y="295" fill="var(--text-muted)">All outputs: TimeDistributed Dense over the French vocabulary, one prediction per output position.</text>
  </g>
</svg>
</div>

| Model | What it adds | Why it should help |
|---|---|---|
| 1 Simple RNN | A GRU reading word ids | Baseline — learns word-to-word mapping |
| 2 Embedding | Dense word vectors instead of raw ids | Similar words get similar representations |
| 3 Bidirectional | Reads the sentence both ways | Each position sees left *and* right context |
| 4 Encoder-decoder | Compress the whole sentence, then generate | Input and output lengths no longer tied |
| 5 Final | Embedding + bidirectional encoder-decoder | All of the above together |

The final model in Keras:

```python
def model_final(input_shape, output_len, en_vocab, fr_vocab):
    inputs = Input(shape=input_shape[1:])
    x = Embedding(input_dim=en_vocab, output_dim=output_len)(inputs)
    x = Bidirectional(GRU(output_len))(x)                      # encoder → one sentence vector
    x = Dense(512, activation="relu")(x)
    x = RepeatVector(output_len)(x)                            # hand that vector to every output step
    x = Bidirectional(GRU(512, return_sequences=True))(x)      # decoder
    outputs = TimeDistributed(Dense(fr_vocab, activation="softmax"))(x)

    model = Model(inputs, outputs)
    model.compile(loss="sparse_categorical_crossentropy",
                  optimizer=Adam(1e-3), metrics=["accuracy"])
    return model
```

## The results — real numbers

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 260" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Validation accuracy: simple RNN 81.9 percent after 20 epochs; embedding 91.7 percent after 15; bidirectional 68.7 percent after 10; encoder-decoder 63.8 percent after 15; final model 77.3 percent after 10 epochs and 88.9 percent after 20">
  <g style="font-size:12px;">
    <!-- scale: 0-100% -> 0-400px, x0=190 -->
    <line x1="190" y1="15" x2="190" y2="225" stroke="var(--border)"/>
    <text x="10" y="40" fill="var(--text)">Simple RNN (20 ep)</text>
    <rect x="190" y="26" width="327" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="524" y="41" fill="var(--text)">81.9%</text>
    <text x="10" y="76" fill="var(--text)" font-weight="700">Embedding (15 ep)</text>
    <rect x="190" y="62" width="367" height="20" rx="3" fill="var(--accent)"/><text x="564" y="77" font-weight="700" fill="var(--accent)">91.7%</text>
    <text x="10" y="112" fill="var(--text)">Bidirectional (10 ep)</text>
    <rect x="190" y="98" width="275" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="472" y="113" fill="var(--text)">68.7%</text>
    <text x="10" y="148" fill="var(--text)">Encoder-decoder (15 ep)</text>
    <rect x="190" y="134" width="255" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="452" y="149" fill="var(--text)">63.8%</text>
    <text x="10" y="184" fill="var(--text)">Final (10 ep)</text>
    <rect x="190" y="170" width="309" height="20" rx="3" fill="var(--text-muted)" fill-opacity="0.6"/><text x="506" y="185" fill="var(--text)">77.3%</text>
    <text x="10" y="220" fill="var(--text)">Final (20 ep)</text>
    <rect x="190" y="206" width="356" height="20" rx="3" fill="var(--accent-strong)" fill-opacity="0.75"/><text x="553" y="221" fill="var(--text)">88.9%</text>
    <text x="190" y="250" fill="var(--text-muted)">validation accuracy, same data, epochs as trained</text>
  </g>
</svg>
</div>

**The "simplest upgrade" won.** Adding an embedding layer took a plain GRU from 81.9% to **91.7%** — better than every more sophisticated architecture under the training budget each got. The final combined model was still climbing at 20 epochs (77.3% → 88.9%) and would likely pass it with more training.

## What the numbers actually say

1. **Embeddings are the highest-value change.** Raw integer ids imply "word 41 is close to word 42," which is nonsense. Learned vectors fix the representation, and everything downstream improves.
2. **Bottleneck architectures are slow starters.** The encoder-decoder squeezes the entire sentence through one 512-dim vector. That's powerful for variable-length translation, but it takes many more epochs to learn — at 15 epochs it was the *worst* model.
3. **Compare at equal training budgets, or you're comparing training time, not architectures.** My epoch counts differed per model, so treat the ranking as "under these budgets," not as a law.
4. **The dataset shapes the winner.** With a tiny vocabulary and near-identical sentence templates, word-to-word alignment is almost one-to-one — exactly what a simple embedding+GRU model is good at. On real-world text with reordering and long sentences, the encoder-decoder (plus **attention**) wins decisively.

## Reading predictions back

The model outputs a probability distribution per position. Take the argmax and map ids back to words:

```python
def logits_to_text(logits, tokenizer):
    index_to_word = {i: w for w, i in tokenizer.word_index.items()}
    index_to_word[0] = "<PAD>"
    return " ".join(index_to_word[i] for i in np.argmax(logits, axis=1)
                    if index_to_word[i] != "<PAD>")
```

## Where to go from here

- **Attention** — let the decoder look back at every encoder state instead of one compressed vector. This is the single biggest jump in NMT quality.
- **Teacher forcing** — feed the decoder the correct previous word during training.
- **Beam search** — keep the top-k partial translations instead of greedy argmax at each step.
- **BLEU score** — accuracy per token is a proxy; BLEU is what the MT field actually reports.
- **Transformers** — drop recurrence entirely. The foundation of everything since 2017.
