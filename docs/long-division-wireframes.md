# Long Division App Wireframes

These wireframes translate the previously discussed layouts into simple, high-level visuals optimized for a mobile portrait experience. Each screen shows the primary interaction zones: the diamond manipulatives, the long-division work area, and the answer submission interface.

## 1. Top-Aligned Manipulative Bar

```
┌──────────────────────────────────────┐
│  Select Diamonds                     │
│  ◇◇◇   ◇◇◇   ◇◇◇   ◇◇◇               │
├──────────────────────────────────────┤
│  Long Division Workspace             │
│  ┌───────┐                           │
│  │ 48 ) 96                           │
│  │-48    │ ← drag grouped diamonds   │
│  │────   │    into each subtraction  │
│  │  48   │    step                   │
│  │ -48   │                           │
│  │────   │                           │
│  │   0   │                           │
│  └───────┘                           │
├──────────────────────────────────────┤
│  Answer Box                          │
│  [   2   ]  ✔ Submit                 │
└──────────────────────────────────────┘
```

*Flow:* Diamonds at the top feed into the central workspace, leading to the answer box directly beneath the calculation area.

## 2. Embedded Manipulative Pane

```
┌──────────────────────────────────────┐
│  Long Division Workspace             │
│  ┌───────┐   Diamonds                │
│  │ 48 ) 96   ┌───────────────┐       │
│  │-48    │   │ ◇◇◇  (x3)     │ ← tap │
│  │────   │   │ ◇◇   (x4)     │    or │
│  │  48   │   │ ◇    (x12)    │ drag │
│  │ -48   │   └───────────────┘       │
│  │────   │   ⇧                         │
│  │   0   │   Grouped diamonds drop    │
│  └───────┘   beside each subtraction  │
├──────────────────────────────────────┤
│  Answer Box                          │
│  [   2   ]  ✔ Submit                 │
└──────────────────────────────────────┘
```

*Flow:* The manipulative panel sits adjacent to the long-division steps, minimizing eye travel between concrete and abstract representations.

## 3. Bottom Dock Answer Box

```
┌──────────────────────────────────────┐
│  Select Diamonds                     │
│  ◇◇◇   ◇◇◇   ◇◇◇   ◇◇◇               │
├──────────────────────────────────────┤
│  Long Division Workspace             │
│  ┌───────┐                           │
│  │ 48 ) 96                           │
│  │-48    │                           │
│  │────   │                           │
│  │  48   │                           │
│  │ -48   │                           │
│  │────   │                           │
│  │   0   │                           │
│  └───────┘                           │
├──────────────────────────────────────┤
│              Answer Dock             │
│  [   2   ]      ✔ Submit             │
└──────────────────────────────────────┘
```

*Flow:* The answer dock anchors the final action at the bottom, supporting thumb reach while keeping manipulatives and workspace aligned above.

---

**Usage Tips**

* Use calming colors and generous spacing around each module to avoid cognitive overload.
* Provide micro-animations (sparkle, pulse) when diamonds snap into a valid group to reinforce learning.
* Keep the answer box large and high-contrast for early readers.
