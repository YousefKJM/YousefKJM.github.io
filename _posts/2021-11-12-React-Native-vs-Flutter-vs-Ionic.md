---
title: "React Native vs Flutter vs Ionic: How to Choose a Mobile Framework"
excerpt: "Forget the language debate. Ionic, React Native and Flutter differ in how they put a button on the screen — and once you see that, the choice gets easy. Notes from shipping both Ionic and native apps."
tags: [Web, mobile, React-Native, Flutter, Ionic]
---
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

I've built mobile apps two ways. At Saudi Aramco's Innovation Center, an IoT access-control app was built with <strong>Ionic, Angular and Cordova</strong> and talked to hardware over Bluetooth Low Energy. For InfoMagnet, my senior project, we wrote <strong>native apps in Swift and Java</strong>.

Picking the wrong approach can cost months, yet most comparisons argue about languages. The more useful question is <strong>how each framework gets a button onto the screen</strong> — that single difference explains almost every trade-off.

## Three ways to draw the screen
The diagram at the top of this article shows the three approaches:

1. **Ionic** — your app is a web app (Angular, React or Vue) running inside a <strong>WebView</strong>, a browser engine embedded in the app. Plugins (Capacitor or Cordova) give access to native features like Bluetooth or the camera.
2. **React Native** — your JavaScript code controls <strong>real native widgets</strong> through a bridge. A button is a real iOS or Android button.
3. **Flutter** — the framework has its <strong>own rendering engine</strong> (Skia) and draws every pixel itself. It doesn't use the platform widgets at all.

Each approach has its own limit: for Ionic it is the WebView, for React Native the traffic over the bridge, and for Flutter the cost of learning Dart and a bigger app size.

## Comparison
| Question | Ionic | React Native | Flutter | Native |
|---|---|---|---|---|
| The team already knows web development? | ✅ best fit | ✅ if they know React | ❌ need to learn Dart | ❌ |
| Same code for a website too? | ✅ it *is* a web app | ⚠️ react-native-web | ⚠️ Flutter web | ❌ |
| Heavy animations / custom UI | ⚠️ | ✅ | ✅ best fit | ✅ |
| Must look exactly like the platform | ⚠️ styled to look similar | ✅ real widgets | ⚠️ re-implemented widgets | ✅ |
| Deep hardware access (BLE, sensors) | ✅ via plugins | ✅ via native modules | ✅ via platform channels | ✅ best fit |
| Newest OS features on day one | ❌ wait for a plugin | ❌ wait for a module | ❌ wait for a plugin | ✅ |

> **Field note:** From the Bluetooth project: the cross-platform UI was never the problem. Every difficult issue ended up in the plugin layer that talks to the hardware. If the core of your app <em>is</em> the hardware, plan time for native code whichever framework you choose.

## Create a project in each framework
All three get you to a running app in about a minute:

```bash
# Ionic (Angular flavour, Capacitor runtime)
npm install -g @ionic/cli
ionic start myapp tabs --type=angular --capacitor
cd myapp && ionic serve                      # runs in the browser first
npx cap add android && npx cap open android  # then opens in Android Studio

# React Native
npx react-native init MyApp
cd MyApp && npx react-native run-android     # or run-ios on macOS

# Flutter
flutter create my_app
cd my_app && flutter run                     # press 'r' for hot reload
flutter doctor                               # if anything doesn't work, start here
```

## The same screen in all three
To see the difference in practice, here is the same list — a list of doors, where tapping one unlocks it, like in the access control app — written in each framework.

<strong>Ionic (Angular template):</strong>

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

<strong>React Native:</strong>

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

<strong>Flutter:</strong>

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

The idea is the same, but the result is different: Ionic creates HTML elements, React Native creates native list cells, and Flutter paints the whole list itself.

## Before releasing any mobile app
1. **Virtualize long lists** (`FlatList`, `ListView.builder`, Ionic virtual scroll). Rendering 1,000 rows at once is the most common performance problem.
2. **Ask for permissions when they are needed**, not when the app starts. Users deny requests they don't understand.
3. **Store secrets in the Keychain / Keystore**, never in `localStorage` or `AsyncStorage` — those are plain text on the device.
4. **Plan for offline use** — save changes locally and sync when the connection is back.
5. **Test on a cheap Android phone.** A flagship phone hides every performance problem.

## My rule of thumb

After working on both cross-platform and native apps, this is how I decide:

- A web team, an app made of forms and lists, maybe a website too → **Ionic**.
- A React team that wants a native look → **React Native**.
- A design-heavy app that must look identical everywhere → **Flutter**.
- The app's main value is the platform itself (hardware, AR, background work) → **native**.

Official docs: <a href="https://ionicframework.com/docs" target="_blank" rel="noopener">Ionic</a>, <a href="https://reactnative.dev/docs/getting-started" target="_blank" rel="noopener">React Native</a> and <a href="https://flutter.dev/docs" target="_blank" rel="noopener">Flutter</a>.
