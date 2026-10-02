---
title: "Vue 3 in One Page: The Composition API Cheat Sheet"
excerpt: "Reactivity, components, props and events, composables, routing, and state — the Vue 3 patterns I reach for constantly, with the Options API equivalent next to each so migrating stops being guesswork."
---

My portfolio site is built in Vue, and Vue 3's Composition API changed how I structure every component. This is the reference I keep open.

## The mental model

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

**Props down, events up, shared state on the side.** If you're passing a prop through three components that don't use it, it belongs in a store.

## Reactivity: `ref` vs `reactive`

```js
import { ref, reactive, computed, watch } from 'vue'

const count = ref(0)                    // primitives → ref, access with .value in JS
const user  = reactive({ name: 'Yousef', role: 'dev' })   // objects → reactive, no .value

const doubled = computed(() => count.value * 2)           // cached, recalculates on change

watch(count, (now, before) => console.log(before, '→', now))
```

| Use | When |
|---|---|
| `ref()` | Primitives, or any value you might reassign entirely |
| `reactive()` | An object you'll mutate in place — **don't destructure it**, you lose reactivity (use `toRefs`) |
| `computed()` | Derived values. Never put side effects in here |
| `watch()` | Side effects on change (API calls, localStorage) |
| `watchEffect()` | Same, but tracks dependencies automatically |

## A complete single-file component

{% raw %}
```vue
<script setup>
import { ref, computed, onMounted } from 'vue'

const props = defineProps({ title: { type: String, required: true } })
const emit  = defineEmits(['selected'])

const items  = ref([])
const filter = ref('')

const visible = computed(() =>
  items.value.filter(i => i.name.toLowerCase().includes(filter.value.toLowerCase()))
)

onMounted(async () => {
  items.value = await (await fetch('/api/items')).json()
})
</script>

<template>
  <h2>{{ props.title }}</h2>
  <input v-model="filter" placeholder="Filter…" />
  <ul>
    <li v-for="item in visible" :key="item.id" @click="emit('selected', item)">
      {{ item.name }}
    </li>
  </ul>
  <p v-if="!visible.length">Nothing matches.</p>
</template>
```
{% endraw %}

`<script setup>` is the shortcut: everything declared at top level is automatically available to the template. No `return {}` boilerplate.

## Options API → Composition API translation

| Options API | Composition API |
|---|---|
| `data() { return { n: 0 } }` | `const n = ref(0)` |
| `computed: { x() {} }` | `const x = computed(() => …)` |
| `methods: { go() {} }` | `function go() {}` |
| `watch: { n(v) {} }` | `watch(n, v => …)` |
| `mounted() {}` | `onMounted(() => {})` |
| `this.$emit('e')` | `const emit = defineEmits(['e']); emit('e')` |
| `props: ['title']` | `const props = defineProps(['title'])` |

## Composables — the real reason to switch

Extract logic into a plain function and reuse it anywhere. This replaces mixins without their name-collision problems.

```js
// composables/useFetch.js
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

// in any component
const { data: projects, loading } = useFetch('/api/projects')
```

## Directives you use daily

{% raw %}
```vue
<p v-if="ok">shown</p> <p v-else>fallback</p>      <!-- removes from DOM -->
<p v-show="ok">toggled</p>                          <!-- CSS display only: cheaper to flip -->
<li v-for="(x, i) in list" :key="x.id">{{ i }}</li> <!-- always give :key a stable id -->
<input v-model.trim="name" />                       <!-- two-way binding, modifiers: .trim .number .lazy -->
<button @click.prevent="save">Save</button>         <!-- @ = v-on, :prop = v-bind -->
<div :class="{ active: isActive }" :style="{ color }"></div>
```
{% endraw %}

## Routing and state in two snippets

```js
// router.js — Vue Router 4
import { createRouter, createWebHistory } from 'vue-router'
export default createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: () => import('./views/Home.vue') },        // lazy-loaded
    { path: '/projects/:id', component: () => import('./views/Project.vue'), props: true },
  ],
})
```

```js
// store.js — for small apps, a reactive object IS a store
import { reactive, readonly } from 'vue'
const state = reactive({ lang: 'en' })
export const store = {
  state: readonly(state),               // components can read but not mutate directly
  setLang(l) { state.lang = l },
}
```

Reach for Vuex/Pinia when you need devtools time-travel, modules, or a team-wide convention. Not before.

## Five mistakes worth avoiding

1. Destructuring `reactive()` — `const { name } = user` breaks reactivity. Use `toRefs(user)`.
2. Using array index as `:key` — reordering a list then reuses the wrong DOM nodes.
3. Mutating props in the child — emit an event and let the parent own the change.
4. `v-if` and `v-for` on the same element — wrap with `<template v-for>` and put `v-if` inside.
5. Forgetting `.value` in `<script>` but adding it in `<template>` — templates unwrap refs automatically; JS doesn't.
