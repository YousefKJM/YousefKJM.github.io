---
title: "React Native vs Flutter vs Ionic: How Each One Actually Draws Pixels"
excerpt: "The real difference between the three big cross-platform frameworks isn't the language — it's how each one gets a button onto the screen. One diagram, one decision table, and starter commands for all three."
---

I've shipped mobile work two ways: an **Ionic/Angular/Cordova** app talking to IoT hardware over BLE (an access control system for Aramco's Innovation Center), and **native Swift + Java** apps for InfoMagnet, my senior project. Picking the wrong approach costs months. The decision gets easy once you see how each framework renders.

## Three rendering strategies

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Ionic renders HTML in a WebView; React Native runs JavaScript that drives real native widgets through a bridge; Flutter draws every pixel itself with its own rendering engine">
  <g style="font-size:12px;">
    <text x="20" y="22" font-weight="700" fill="var(--accent)">IONIC</text>
    <text x="230" y="22" font-weight="700" fill="var(--accent)">REACT NATIVE</text>
    <text x="440" y="22" font-weight="700" fill="var(--accent)">FLUTTER</text>
    <!-- Ionic -->
    <rect x="10" y="34" width="190" height="44" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="61" fill="var(--text)">Angular / React / Vue + HTML</text>
    <rect x="10" y="88" width="190" height="44" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="115" fill="var(--text)">WebView (browser engine)</text>
    <rect x="10" y="142" width="190" height="44" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="169" fill="var(--text)">Capacitor/Cordova plugins</text>
    <rect x="10" y="196" width="190" height="44" rx="6" fill="none" stroke="var(--text-muted)"/>
    <text x="22" y="223" fill="var(--text-muted)">Native APIs (BLE, camera)</text>
    <!-- RN -->
    <rect x="220" y="34" width="190" height="44" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="232" y="61" fill="var(--text)">React components (JS)</text>
    <rect x="220" y="88" width="190" height="44" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="232" y="115" fill="var(--text)">Bridge / JSI</text>
    <rect x="220" y="142" width="190" height="98" rx="6" fill="none" stroke="var(--text-muted)"/>
    <text x="232" y="180" fill="var(--text-muted)">Real native widgets</text>
    <text x="232" y="200" fill="var(--text-muted)">UIView / android.view</text>
    <!-- Flutter -->
    <rect x="430" y="34" width="200" height="44" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="442" y="61" fill="var(--text)">Widgets (Dart)</text>
    <rect x="430" y="88" width="200" height="98" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="442" y="126" fill="var(--text)">Own rendering engine</text>
    <text x="442" y="146" fill="var(--text-muted)">paints every pixel to</text>
    <text x="442" y="164" fill="var(--text-muted)">a canvas (Skia)</text>
    <rect x="430" y="196" width="200" height="44" rx="6" fill="none" stroke="var(--text-muted)"/>
    <text x="442" y="223" fill="var(--text-muted)">Platform channels → native</text>
    <text x="10" y="272" fill="var(--text)" font-weight="700">Web skills, one codebase</text>
    <text x="220" y="272" fill="var(--text)" font-weight="700">Native look, JS team</text>
    <text x="430" y="272" fill="var(--text)" font-weight="700">Pixel control, consistent UI</text>
    <text x="10" y="290" fill="var(--text-muted)">perf ceiling: the WebView</text>
    <text x="220" y="290" fill="var(--text-muted)">perf ceiling: bridge traffic</text>
    <text x="430" y="290" fill="var(--text-muted)">cost: Dart + larger binary</text>
  </g>
</svg>
</div>

## Decision table

| Question | Ionic | React Native | Flutter | Native |
|---|---|---|---|---|
| Team already knows web? | ✅ best fit | ✅ if React | ❌ learn Dart | ❌ |
| Ship to web too, same code? | ✅ it *is* web | ⚠️ react-native-web | ⚠️ Flutter web | ❌ |
| Heavy animation / custom UI | ⚠️ | ✅ | ✅ best fit | ✅ |
| Must look exactly like the platform | ⚠️ styled to mimic | ✅ real widgets | ⚠️ re-implements them | ✅ |
| Deep hardware (BLE, sensors) | ✅ via plugins | ✅ via modules | ✅ via channels | ✅ best fit |
| Newest OS APIs on day one | ❌ wait for plugin | ❌ wait for module | ❌ wait for plugin | ✅ |

**Lesson from the BLE project:** cross-platform was fine for the UI, but every hardware edge case ended in the plugin layer. If the core of your app *is* the hardware, budget native time either way.

## Start each one in under a minute

```bash
# Ionic (Angular flavour, Capacitor runtime)
npm install -g @ionic/cli
ionic start myapp tabs --type=angular --capacitor
cd myapp && ionic serve                      # runs in the browser first
npx cap add android && npx cap open android  # then into Android Studio

# React Native
npx react-native init MyApp
cd MyApp && npx react-native run-android     # or run-ios on macOS

# Flutter
flutter create my_app
cd my_app && flutter run                     # hot reload with 'r'
flutter doctor                               # when anything doesn't work, start here
```

## The same "list + tap" screen in all three

**Ionic (Angular template)**
{% raw %}
```html
<ion-list>
  <ion-item *ngFor="let door of doors" (click)="unlock(door)">
    <ion-label>{{ door.name }}</ion-label>
    <ion-badge slot="end">{{ door.status }}</ion-badge>
  </ion-item>
</ion-list>
```
{% endraw %}

**React Native**
```jsx
<FlatList
  data={doors}
  keyExtractor={d => d.id}
  renderItem={({ item }) => (
    <TouchableOpacity onPress={() => unlock(item)}>
      <Text>{item.name} · {item.status}</Text>
    </TouchableOpacity>
  )}
/>
```

**Flutter**
```dart
ListView.builder(
  itemCount: doors.length,
  itemBuilder: (context, i) => ListTile(
    title: Text(doors[i].name),
    trailing: Text(doors[i].status),
    onTap: () => unlock(doors[i]),
  ),
);
```

Same idea, three rendering models: Ionic emits DOM elements, React Native emits native list cells, Flutter paints the whole list itself.

## Production checklist (any framework)

1. **Virtualize long lists** — `FlatList`, `ListView.builder`, `ion-virtual-scroll`/CDK. Rendering 1,000 rows at once is the most common perf bug.
2. **Request permissions at the moment of use**, not on launch. Users deny upfront prompts they don't understand.
3. **Store secrets in Keychain/Keystore**, never in `localStorage` or `AsyncStorage` — those are plaintext on disk.
4. **Plan for offline** — queue writes locally, sync on reconnect.
5. **Test on a cheap Android device.** Your flagship phone hides every performance problem.

## My rule of thumb

- Web team, forms-and-lists app, maybe also a web version → **Ionic**.
- React team, needs native feel → **React Native**.
- Design-heavy, brand-consistent UI across platforms → **Flutter**.
- The app's core value is the platform itself (hardware, AR, background processing) → **native**.
