---
title: "Neural Machine Translation with RNNs in Keras"
excerpt: "Five RNN architectures, one English-to-French dataset, real validation numbers. The surprise: the simplest upgrade — an embedding layer — beat the fancy encoder-decoder."
header:
  image: /images/posts/machine-translation/rnn.png
tags: [AI, NLP, RNN, Keras, deep-learning]
---
![Recurrent neural network for translation](/images/posts/machine-translation/rnn.png)

[Tagging words](/HMM-Part-of-Speech-Tagging-with-Viterbi/) with counts was one thing. Translation is a much harder sequence problem: read a whole sentence in one language, write it in another, where word order changes and the lengths don't match.

For an individual project I built an <strong>English → French translator</strong> with recurrent neural networks in Keras and compared five architectures on the same data. The numbers taught me more than the architecture diagrams did. Code is on <a href="https://github.com/YousefKJM/P2-Machine-Translation" target="_blank" rel="noopener">GitHub</a>.

## A short history of machine translation
Before building anything, the project started by looking at how machine translation evolved:

| Era | Approach | Idea | Weakness |
|---|---|---|---|
| 1950s–80s | **Rule-based** | Linguists write grammar rules and dictionaries by hand | Doesn't scale; every exception needs a new rule |
| 1990s–2014 | **Statistical** | Learn phrase translation probabilities from parallel texts | Translates phrase by phrase, clumsy word order |
| — | **Example-based** | Translate by analogy with stored sentence pairs | Limited to what was seen before |
| 2014+ | **Neural** | One network reads the whole sentence and writes the whole translation | Needs a lot of data |

## The data and preprocessing
The dataset has <strong>137,860 English–French sentence pairs</strong> with a small vocabulary, for example:

```
new jersey is sometimes quiet during autumn , and it is snowy in april .
new jersey est parfois calme pendant l' automne , et il est neigeux en avril .
```

Data first. Neural networks work with numbers, not words, so every pipeline needs the same three steps — turn words into ids, make all sentences the same length, and reshape the labels:

```python
from keras.preprocessing.text import Tokenizer
from keras.preprocessing.sequence import pad_sequences

def tokenize(sentences):
    tk = Tokenizer()
    tk.fit_on_texts(sentences)                    # word -> integer id
    return tk.texts_to_sequences(sentences), tk

def pad(seqs, length=None):
    return pad_sequences(seqs, maxlen=length, padding="post")   # zeros at the end

x, x_tk = tokenize(english);  x = pad(x)
y, y_tk = tokenize(french);   y = pad(y)
y = y.reshape(*y.shape, 1)    # sparse_categorical_crossentropy needs this extra dimension
```

## The five models
Then the models, one by one — each adds a single idea to the previous one:

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

<strong>1. Simple RNN</strong> — a GRU layer reads the word ids and a dense softmax layer predicts a French word at every position. This is the baseline, shown in the picture at the top of the article.

<strong>2. Embedding</strong> — instead of raw ids, every word becomes a learned vector, so similar words get similar representations:

<img src="/images/posts/machine-translation/embedding.png" alt="Embedding layer" width="560" style="margin-inline:auto;" />

<strong>3. Bidirectional RNN</strong> — the sentence is read in both directions, so every position sees the words before and after it:

<img src="/images/posts/machine-translation/bidirectional.png" alt="Bidirectional RNN" width="600" style="margin-inline:auto;" />

<strong>4. Encoder-decoder</strong> — the encoder compresses the whole sentence into one vector, and the decoder generates the translation from it. This removes the requirement that input and output have the same length.

<strong>5. Final model</strong> — all of the above together. This is the Keras code:

```python
def model_final(input_shape, output_len, en_vocab, fr_vocab):
    inputs = Input(shape=input_shape[1:])
    x = Embedding(input_dim=en_vocab, output_dim=output_len)(inputs)
    x = Bidirectional(GRU(output_len))(x)                      # encoder -> one sentence vector
    x = Dense(512, activation="relu")(x)
    x = RepeatVector(output_len)(x)                            # give that vector to every output step
    x = Bidirectional(GRU(512, return_sequences=True))(x)      # decoder
    outputs = TimeDistributed(Dense(fr_vocab, activation="softmax"))(x)

    model = Model(inputs, outputs)
    model.compile(loss="sparse_categorical_crossentropy",
                  optimizer=Adam(1e-3), metrics=["accuracy"])
    return model
```

## The results
These are the real validation accuracies from my notebook:

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

The winner was <strong>not</strong> the most advanced model. Simply adding an embedding layer took the plain GRU from 81.9% to <strong>91.7%</strong> — better than every more complex architecture with the training each one got. The final model was still improving at 20 epochs (77.3% → 88.9%), so with more training it would probably pass it.

What do these numbers tell us?

1. **Embeddings are the most valuable change.** Raw ids suggest that "word 41 is close to word 42", which means nothing. Learned vectors fix the representation, and everything after it improves.
2. **Encoder-decoder models learn slowly at the start.** Squeezing the whole sentence into one 512-number vector is powerful, but at 15 epochs it was actually the worst model.
3. **Compare models with the same training budget.** My models were trained for different numbers of epochs, so this ranking is "under these budgets", not a general rule.
4. **The dataset decides a lot.** With a small vocabulary and very similar sentences, words map almost one-to-one, which is exactly what embedding + GRU is good at. On real text with long sentences and word reordering, encoder-decoder models with <strong>attention</strong> win clearly.

> **Reading the output:** The model outputs a probability for every French word at every position. To read the translation, take the most likely word at each position and map the ids back to words, skipping the padding:

```python
def logits_to_text(logits, tokenizer):
    index_to_word = {i: w for w, i in tokenizer.word_index.items()}
    index_to_word[0] = "<PAD>"
    return " ".join(index_to_word[i] for i in np.argmax(logits, axis=1)
                    if index_to_word[i] != "<PAD>")
```

## What the numbers taught me

Five models on the same data showed that architecture diagrams don't tell the whole story: the embedding layer gave the biggest jump, the encoder-decoder needed far more training, and the dataset itself favoured the simpler model. The natural next steps are attention, beam search instead of greedy decoding, BLEU for evaluation — and finally Transformers, which dropped recurrence altogether. The notebook is on <a href="https://github.com/YousefKJM/P2-Machine-Translation" target="_blank" rel="noopener">GitHub</a>; the architecture diagrams come from Udacity's project template (MIT licence).
