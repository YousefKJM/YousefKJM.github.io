---
title: "Getting Started with the Vue 3 Composition API"
excerpt: "In this article I would like to present the Vue 3 Composition API by building a small working component step by step — reactivity, props and events, composables, and how each piece maps to the Options API you may already know."
header:
  image: /images/posts/vue-3/project-list.png
---

<p align="center">
<img src="/images/posts/vue-3/project-list.png" alt="A small Vue 3 app listing projects" width="640" style="margin-inline:auto;"/>
</p>

<h3><strong>Short introduction</strong></h3>
My personal portfolio website is built with Vue.js, and Vue is the frontend framework I use the most in my web development work. With Vue 3 — and especially the <code>&lt;script setup&gt;</code> syntax that became stable in Vue 3.2 this month — the <strong>Composition API</strong> changed the way I write components. In this article I would like to present it by building the small app in the picture above: a list of my projects with a live filter, where clicking a project tells the parent component which one was selected. Along the way, I will show how each part maps to the Options API.

&nbsp;
<h3><strong>Create the project</strong></h3>
Lets start by creating a new Vue 3 project with Vite:

```bash
npm create vite@latest vue-demo -- --template vue
cd vue-demo
npm install
npm run dev
```

For the data I used a simple JSON file in `public/api/items.json`, so we can focus on Vue and not on a backend:

```json
[
  {"id": 1, "name": "Personal Website", "tech": "Vue.js"},
  {"id": 2, "name": "Mon9et", "tech": "Django"},
  {"id": 3, "name": "Academy Platform", "tech": "PHP / Node.js"}
]
```

&nbsp;
<h3><strong>How data flows between components</strong></h3>
Before writing the component, it helps to understand the rule that every Vue app follows:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 210" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Vue data flow: parent passes props down to child, child emits events up, shared state lives in a store or composable both can use">
  <defs><marker id="vu-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:13px;">
    <rect x="40" y="20" width="200" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="104" y="53" font-weight="700" fill="var(--text)">Parent</text>
    <rect x="40" y="134" width="200" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="110" y="167" font-weight="700" fill="var(--text)">Child</text>
    <line x1="110" y1="76" x2="110" y2="130" stroke="var(--accent)" stroke-width="2" marker-end="url(#vu-arr)"/>
    <text x="60" y="108" fill="var(--accent)" font-weight="700">props ↓</text>
    <line x1="170" y1="134" x2="170" y2="80" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#vu-arr)"/>
    <text x="178" y="108" fill="var(--text-muted)" font-weight="700">emit ↑</text>
    <rect x="390" y="76" width="220" height="60" rx="10" fill="none" stroke="var(--accent)" stroke-width="2" stroke-dasharray="6 4"/>
    <text x="410" y="102" font-weight="700" fill="var(--text)">Store / composable</text>
    <text x="410" y="122" fill="var(--text-muted)">shared state, not prop-drilled</text>
    <line x1="240" y1="48" x2="386" y2="96" stroke="var(--border)" stroke-width="2"/>
    <line x1="240" y1="162" x2="386" y2="118" stroke="var(--border)" stroke-width="2"/>
  </g>
</svg>
</div>

<strong>Props go down, events go up, and shared state lives on the side.</strong> If you find yourself passing a prop through three components that don't use it, it belongs in a store or a composable.

&nbsp;
<h3><strong>Reactivity: ref and reactive</strong></h3>
Everything in the Composition API starts with reactive values:

```js
import { ref, reactive, computed, watch } from 'vue'

const count = ref(0)                                      // primitives -> ref, use .value in JS
const user  = reactive({ name: 'Yousef', role: 'dev' })   // objects -> reactive, no .value

const doubled = computed(() => count.value * 2)           // cached, recalculated on change
watch(count, (now, before) => console.log(before, '→', now))
```

| Use | When |
|---|---|
| `ref()` | Primitives, or any value you may replace completely |
| `reactive()` | An object you change in place — **don't destructure it**, you lose reactivity (use `toRefs`) |
| `computed()` | Values derived from other values. No side effects inside |
| `watch()` | Side effects when something changes (API calls, localStorage) |

&nbsp;
<h3><strong>A composable for fetching data</strong></h3>
In this section we will write our first <strong>composable</strong> — a plain function that contains reactive logic and can be reused by any component. This is the main reason to use the Composition API: it replaces mixins without their name collisions. Create `src/composables/useFetch.js`:

```js
import { ref } from 'vue'

export function useFetch(url) {
  const data = ref(null), error = ref(null), loading = ref(true)
  fetch(url)
    .then(r => r.ok ? r.json() : Promise.reject(r.statusText))
    .then(d => (data.value = d))
    .catch(e => (error.value = e))
    .finally(() => (loading.value = false))
  return { data, error, loading }
}
```

&nbsp;
<h3><strong>The component</strong></h3>
Now the component itself, `src/components/ProjectList.vue`. It receives a `title` prop, loads the data with our composable, filters it with a computed value, and emits a `selected` event when an item is clicked:

{% raw %}
```vue
<script setup>
import { ref, computed } from 'vue'
import { useFetch } from '../composables/useFetch'

const props = defineProps({ title: { type: String, required: true } })
const emit  = defineEmits(['selected'])

const { data: items, loading } = useFetch('/api/items.json')
const filter = ref('')

const visible = computed(() =>
  (items.value || []).filter(i => i.name.toLowerCase().includes(filter.value.toLowerCase()))
)
</script>

<template>
  <h2>{{ props.title }}</h2>
  <input v-model="filter" placeholder="Filter…" />
  <p v-if="loading">Loading…</p>
  <ul v-else>
    <li v-for="item in visible" :key="item.id" @click="emit('selected', item)">
      <strong>{{ item.name }}</strong> <span class="tech">{{ item.tech }}</span>
    </li>
  </ul>
  <p v-if="!loading && !visible.length">Nothing matches.</p>
</template>
```
{% endraw %}

With `<script setup>`, everything declared at the top level is automatically available in the template. There is no `return { ... }` and no `export default`.

And the parent, `src/App.vue`, listens to the event:

{% raw %}
```vue
<script setup>
import { ref } from 'vue'
import ProjectList from './components/ProjectList.vue'
const picked = ref(null)
</script>

<template>
  <ProjectList title="My Projects" @selected="p => (picked = p)" />
  <p v-if="picked">Selected: <strong>{{ picked.name }}</strong></p>
</template>
```
{% endraw %}

Once you save, the app shows the full list as in the first screenshot. Type "rec" in the filter and click the result — the list updates on every key press, and the parent receives the selected item through the event:

<img src="/images/posts/vue-3/filter-and-emit.png" alt="Filtered list with the selected project" width="640" style="margin-inline:auto;" />

&nbsp;
<h3><strong>Options API → Composition API</strong></h3>
If you already know Vue 2, this table maps what you know to the new syntax:

| Options API | Composition API |
|---|---|
| `data() { return { n: 0 } }` | `const n = ref(0)` |
| `computed: { x() {} }` | `const x = computed(() => …)` |
| `methods: { go() {} }` | `function go() {}` |
| `watch: { n(v) {} }` | `watch(n, v => …)` |
| `mounted() {}` | `onMounted(() => {})` |
| `this.$emit('e')` | `const emit = defineEmits(['e']); emit('e')` |
| `props: ['title']` | `const props = defineProps(['title'])` |

> **_NOTE:_**  Five common mistakes: destructuring a `reactive()` object (use `toRefs`), using the array index as `:key`, changing a prop inside the child (emit an event instead), putting `v-if` and `v-for` on the same element, and forgetting `.value` in the script — templates unwrap refs automatically, JavaScript doesn't.

&nbsp;
<h3><strong>Summary</strong></h3>
The Composition API organizes a component by what it does instead of by option type: reactive values with `ref` and `reactive`, derived values with `computed`, communication with props and events, and reusable logic in composables. The small app in this article uses all of them in less than 50 lines. You can read more in the official <a href="https://v3.vuejs.org/guide/composition-api-introduction.html" target="_blank" rel="noopener">Vue 3 documentation</a>.
