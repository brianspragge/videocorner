# Omarchy Plugin Style Guide

Shared conventions for `monk.videocorner` and `monk.gofind`. Both plugins must
follow these rules so they read as one consistent codebase.

## 1. File header comments

Every `.qml` and `.js` file starts with a **3–5 line comment** describing the
component's role, what it owns, and what it does *not* touch. Place it
**before** the root type declaration (after the imports).

- Views describe what they render and what signals they emit.
- Services state that they "do not open, close, or size the panel."
- Model.js states it is Qt-free and unit-testable under node.

Example (service):
```
// Owns the <X> lifecycle. It does not open, close, or size the panel — the
// root binds inputs and calls the entry functions. State (…) is read by the root.
```

Example (Model.js):
```
// Pure <logic> for <plugin>. Everything here is Qt-free so it can be unit
// tested under node (test/shell.d/<plugin>-test.sh); the QML owns UI, key
// handling, and Process runs.
```

## 2. Imports order

Always in this order:

```qml
import QtQuick
import QtQuick.Controls        // only if Qt Quick Controls types are used
import Quickshell
import Quickshell.Io           // only if Process/StdioCollector used
import qs.Commons
import qs.Ui
import "Model.js" as Model     // only if Model.js is actually referenced
```

- **Do not import what you don't use.** (e.g. drop `Model.js` from
  `BarWidget.qml` if it's never referenced.)

## 3. Root id and self-reference

- Every component uses `id: root` and refers to itself as `root.*` (never a
  bare property name, except within the owning component's own scope where it's
  unambiguous).

## 4. Root `Panel.qml` structure

Order consistently top-to-bottom:

1. Header comment
2. `Panel { id: root }`, `moduleName`, `ipcTarget`, `manageIpc`
3. `anchorItem` / `hostWidget` / `barIdentity`
4. Color props: `foreground`, `dim`, `fontFamily`
5. Shared state `property` block
6. `readonly` derived `property` block
7. **Section-marker comments** `// ---- <section> ----` separating:
   - lifecycle (`open` / `close` / `toggle` / `switchPanel`)
   - settings / persistence
   - search
   - cursor / actions
   - services (component instances)
   - key handling (`KeyboardPanel` + `keyCatcher`)
8. Wiring only via signals / `onXxx:` handlers — **no child calls into siblings**.

Keep section markers wide and consistent, e.g.:
```
  // ---- open / close --------------------------------------------------------
```

## 5. View components (suffix `View`)

- Base type `Item` (or `Popup` only for popup-style views like context menus /
  app pickers).
- Layout order:
  1. `required property` block
  2. `signal` block
  3. helper functions
  4. visual tree
- **Signal naming is verb + noun** describing the event: `activateRow`,
  `browse`, `chooseApp`, `play`, `back`. Avoid `set*` names for signals (a
  `setX` name reads like a setter, not an event).
- Report `implicitHeight` (or `contentImplicitHeight`) so the root can size the
  panel.
- Pure visual: never opens/closes the panel or reaches into the root's
  internals.

## 6. Service components (suffix `Service`)

- Base type `Item`.
- Own its `Process` / `Timer` and state.
- Expose inputs as `property`, outputs as `signal`.
- Never touch panel lifecycle or size.

## 7. Model.js conventions

- Header comment per §1.
- Group related functions with `// ---- <section> ----` markers.
- `module.exports` at the bottom, listing exported symbols.

## 8. Keybindings

- `keyCatcher` is a custom `Item` with:
  ```qml
  focus: true
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) { … }
  ```
- Modifier checks are consistent within a plugin.

## 9. Spacing tokens

Use the **same spacing idiom within a file and across the two plugins** —
prefer `Style.spacing.*` (semantic tokens like `Style.spacing.sm`) for
consistent rhythm; `Style.space(px)` only where a literal pixel-ish gap is
intended. Pick one per use case and stay consistent.

## 10. Property placement

Group all `property` declarations at the top of the component (with the
shared-state / readonly blocks), **not** interleaved between functions or
`Process` blocks. A property used by an early function must still be declared
in the top block.
