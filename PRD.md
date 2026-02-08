# Tymark — Product Requirements Document & Implementation Plan

> **A lightweight, performant markdown viewer and editor built with SwiftUI.**
> *"The markdown editor Apple would build if Apple built a markdown editor."*

---

## Context

The markdown editor market is valued at **$1.21B (2024)** and projected to reach **$3.44B by 2033** (12.3% CAGR). Yet every popular inline-rendering editor (Typora, Obsidian) runs on Electron — wrapping web browsers in desktop shells, consuming 300-800MB of RAM for a text file. Apple has shipped TextKit 2, matured SwiftUI into a production-grade framework, and delivered first-class `AttributedString` support. The technical foundation for a truly native markdown editor now exists. Nobody has built it properly yet.

Tymark fills this gap: a native-first, performance-obsessed markdown editor for macOS (and later iOS/iPadOS) that delivers Typora-style inline WYSIWYG rendering at **10x the speed** of Electron-based competitors.

---

## Part I: Product Requirements Document

---

### 1. Problem Statement

| # | Problem | Impact |
|---|---------|--------|
| 1 | **Performance poverty** — Electron editors lag on 500+ line docs, consume 300-800MB RAM | 68% of users cite "preview lag" as a top pain point |
| 2 | **Split-pane cognitive tax** — Raw source left, preview right creates constant context-switching | Only Typora solves this, but it's Electron |
| 3 | **Subscription fatigue** — Ulysses ($50/yr), Bear ($15/yr) for what users see as a text editor | Typora's one-time $15 is the most-loved pricing model |
| 4 | **Missing system integration** — No Quick Look for `.md` files, no Spotlight indexing, no Handoff | Editors feel like visitors, not macOS residents |
| 5 | **Extension vs. simplicity** — Obsidian = powerful but complex; iA Writer = simple but rigid | No editor occupies the intersection |

---

### 2. Target Users

**Dev Dana** (Developer Writer, age 28-40) — Writes READMEs, ADRs, docs. Uses VS Code for code but wants a dedicated writing environment. Pain: "My editor shouldn't consume more RAM than my IDE." WTP: $20-40.

**Creator Claire** (Content Creator, age 25-45) — Blogger, newsletter writer. Cares about typography, focus mode, export. Pain: "I just want to write without the app getting in my way." WTP: $25-50.

**Academic Alex** (Researcher, age 25-55) — Writes papers with LaTeX math, citations. Needs Mermaid diagrams, footnotes, tables. Pain: "I need LaTeX inline but not a full LaTeX IDE." WTP: $30-50.

**Notes Nadia** (Power User, age 22-40) — Personal knowledge management. Values speed of capture above all. Pain: "Obsidian is powerful but slow and drains my battery." WTP: $15-30.

---

### 3. Product Principles

1. **Performance is a feature.** Every interaction < 16ms. 10,000-line doc scrolls like a 10-line doc. Memory < 100MB.
2. **Native is non-negotiable.** System fonts, system appearance, Spotlight, Quick Look, Shortcuts, Handoff.
3. **Invisible until needed.** Markdown syntax transforms inline, controls surface contextually. Zero chrome by default.
4. **Simple defaults, powerful options.** Zero-config first launch. Power users customize themes, keybindings, and extensions.
5. **Own the file.** Plain `.md` files on disk. No proprietary formats, no lock-in, no database wrappers.
6. **Speed of thought.** Cmd+N to first keystroke feels instantaneous. Typing `# ` to seeing a heading feels instantaneous.

---

### 4. Core Features (MVP — v1.0)

#### 4.1 Inline WYSIWYG Rendering (Typora-Style)

The signature feature. As users type markdown syntax, it transforms inline into rendered output:

- `# Heading` becomes a styled heading (`#` hidden, revealed on cursor entry)
- `**bold**` becomes **bold** (asterisks hidden)
- Fenced code blocks render with syntax highlighting
- Images render inline with adjustable display size
- Tables render as formatted, editable tables
- **Cursor proximity reveal:** When the cursor enters a rendered element, the markdown syntax fades in for editing. When the cursor leaves, it re-renders.

**Technical approach:** Custom `NSTextView` subclass (bridged via `NSViewRepresentable`) using TextKit 2's `NSTextContentManager` and `NSTextLayoutManager`. Pipeline:

1. Parse document into AST via Apple's `swift-markdown`
2. Map AST nodes to `NSAttributedString` ranges with custom attributes
3. Use TextKit 2 layout fragments for inline transformations
4. Cursor-proximity detection toggles source/rendered mode per-element

#### 4.2 Performance Engine

| Benchmark | Target | Competitive Baseline |
|-----------|--------|---------------------|
| Cold launch | < 500ms | Typora: ~2s, Obsidian: ~3s |
| Open 1,000-line doc | < 100ms | Typora: ~300ms |
| Keystroke-to-render | < 8ms (120Hz) | Typora: ~30ms |
| Scroll FPS (10k lines) | 60fps+ | Typora: ~30fps with jank |
| Memory idle | < 50MB | Typora: ~150MB, Obsidian: ~300MB |
| Memory (5k-line doc) | < 100MB | Typora: ~400MB |
| App binary size | < 25MB | Typora: ~80MB, Obsidian: ~300MB |

Achieved through: **incremental parsing** (re-parse only the edited block), **lazy rendering** (compute attributes only for visible viewport + 2-screen buffer), **background processing** (Swift concurrency for heavy operations).

#### 4.3 System Integration

- **Spotlight indexing** — Register as importer for `.md` files. Index titles, headings, full text.
- **Quick Look extension** — Space in Finder shows rendered markdown preview.
- **Share extension** — "Open in Tymark" / "Share to Tymark" system extensions.
- **Shortcuts integration** — Actions: Create Document, Open, Export to PDF, Search.
- **Drag and drop** — Drop images to embed, drop `.md` files to open.

#### 4.4 iCloud Sync

`NSDocument` subclass with iCloud Document storage. Transparent sync, conflict resolution, auto-save, Time Machine versioning. Also supports local-only documents.

#### 4.5 Customizable Themes

6 built-in themes (Light, Dark, Sepia, Nord, Solarized Light/Dark). Custom themes via JSON. Typography controls (font, size, line height, page width). Focus mode (dims all paragraphs except current).

#### 4.6 File Browser / Workspace Management

Sidebar file tree, multiple workspaces, Quick Open (Cmd+P) with fuzzy search, tab interface, outline view (heading structure), file operations (create/rename/delete/move).

#### 4.7 Export

PDF (customizable styles), HTML (clean semantic), DOCX, Copy as Rich Text, Print.

#### 4.8 Keyboard-First UX

Command Palette (Cmd+Shift+P), optional Vim mode, customizable keybindings (JSON), standard macOS shortcuts, smart pairs/lists.

---

### 5. Post-MVP Roadmap

| Release | Timeline | Key Features |
|---------|----------|--------------|
| **v1.1** | Launch + 2mo | Find/Replace (regex), zen mode, document statistics, smart typography |
| **v1.2** | Launch + 5mo | Mermaid diagrams, LaTeX/KaTeX math, footnotes, YAML front matter, image paste |
| **v1.5** | Launch + 9mo | AI Writing Assistant — local (Core ML) + cloud (Claude API). Privacy-first: local by default, cloud opt-in |
| **v2.0** | Launch + 15mo | iOS/iPadOS companion, plugin/extension system (Swift API), Git integration, collaboration (CRDTs), visionOS (exploratory) |

---

### 6. Business Model

#### Pricing: One-Time Purchase + AI Subscription

| Tier | Price | Includes |
|------|-------|----------|
| **Tymark Free** | $0 | Full editor, inline rendering, 2 themes, single doc, basic export |
| **Tymark Pro (macOS)** | $29 one-time | All themes + custom, workspaces, full export, command palette, system integrations, iCloud sync, focus mode |
| **Tymark Pro (iOS)** | $14.99 one-time | Full features adapted for touch. Bundle: $39 Mac+iOS |
| **Tymark AI Pack** | $9.99/yr or $1.99/mo | Cloud AI features (Claude/OpenAI). Local AI included free in Pro |

#### Revenue Projections (Conservative)

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| Free downloads | 50,000 | 150,000 | 300,000 |
| Pro conversion rate | 8% | 10% | 12% |
| Pro revenue | $116,000 | $435,000 | $1,044,000 |
| iOS revenue | — | $74,950 | $299,800 |
| AI Pack revenue | — | $59,880 | $299,400 |
| **Net Revenue** (after 15% App Store cut) | **$98,600** | **$484,355** | **$1,396,720** |

---

### 7. Go-to-Market Strategy

1. **Community Seeding (pre-launch, 3 months):** Open-source the parser module on GitHub. Dev blog series "Building a Native Markdown Editor with TextKit 2" (targeting HN, Swift community). TestFlight beta with 500-1,000 testers from r/macapps, r/markdown, HN.

2. **Launch:** Product Hunt (#1 POTD target). HN "Show HN" leading with performance benchmarks. MacStories, 9to5Mac, The Sweet Setup reviews.

3. **Growth:** Apple editorial outreach (native SwiftUI = exactly what Apple promotes). Setapp inclusion. Education discount (50%). Theme marketplace. Localization (JP, KR, CN, DE, FR).

4. **Expansion:** iOS launch, enterprise/team licenses, international markets.

---

### 8. Competitive Positioning

| Feature | Tymark | Typora | iA Writer | Obsidian | Bear |
|---------|--------|--------|-----------|----------|------|
| Native macOS | **SwiftUI** | Electron | AppKit | Electron | AppKit |
| Inline WYSIWYG | **Yes** | Yes | No | No | Partial |
| Perf (10k lines) | **120fps** | Laggy | N/A | Laggy | N/A |
| Memory usage | **< 100MB** | ~300MB | ~80MB | ~500MB | ~100MB |
| iCloud sync | **Native** | No | Native | Paid | Native |
| Spotlight/Quick Look | **Yes** | No | Partial | No | Partial |
| Price | $29 once | $15 once | $30/platform | Free/$50/yr | $15/yr |
| AI writing | v1.5 | No | No | Plugin | No |

---

### 9. Defensible Moat

1. **Performance moat:** TextKit 2 + native rendering is architecturally impossible to replicate in Electron
2. **Ecosystem moat:** Deep macOS integration (Spotlight, Quick Look, Shortcuts) creates switching costs
3. **Platform moat:** Single codebase expandable to iOS/iPadOS/visionOS via SwiftUI
4. **Distribution moat:** Mac App Store + Apple editorial features for quality native apps

---

### 10. Risk Analysis

| Risk | Severity | Mitigation |
|------|----------|------------|
| TextKit 2 bugs prevent inline rendering | High | Build POC first (week 1-2). Fallback to TextKit 1 for specific fragments |
| Apple builds a native markdown editor | Critical/Low prob | Dedicated tools retain value (Fantastical vs Calendar). Depth > breadth |
| Low Free-to-Pro conversion | High | A/B test feature gate. Free useful for WoM but limited enough to motivate upgrade |
| Incremental parsing correctness | Medium | 500+ test cases. Fallback to full re-parse when ambiguous |
| Solo developer bus factor | High | Modular architecture, document everything, open-source non-core modules |

---

## Part II: Technical Implementation Plan

---

### 11. Architecture

```
+-----------------------------------------------------------+
|                   Tymark Application                      |
+-----------------------------------------------------------+
|  Presentation (SwiftUI)                                   |
|  +----------------+  +----------------+  +-------------+  |
|  |  EditorView    |  |  SidebarView   |  |  ExportView |  |
|  |  (NSViewRep.)  |  |  (Files,       |  |  (PDF, HTML,|  |
|  |                |  |   Outline)     |  |   DOCX)     |  |
|  +----------------+  +----------------+  +-------------+  |
+-----------------------------------------------------------+
|  Domain Layer                                             |
|  +--------------+ +--------------+ +-------------------+  |
|  |  Markdown    | |   Theme      | |    Workspace      |  |
|  |  Engine      | |   Engine     | |    Manager        |  |
|  +--------------+ +--------------+ +-------------------+  |
|  +--------------+ +--------------+ +-------------------+  |
|  |   Sync       | |   Export     | |    Keybinding     |  |
|  |   Engine     | |   Engine     | |    Engine         |  |
|  +--------------+ +--------------+ +-------------------+  |
+-----------------------------------------------------------+
|  Platform Layer                                           |
|  +------------------+ +------------+ +-----------------+  |
|  | TextKit 2        | | FileSystem | | Spotlight/QL/   |  |
|  | Bridge           | |            | | Share Extensions|  |
|  +------------------+ +------------+ +-----------------+  |
+-----------------------------------------------------------+
```

---

### 12. Project Structure (SPM Workspace)

```
Tymark/
├── Package.swift                     # Root workspace
├── App/
│   ├── Tymark/                       # macOS app target
│   │   ├── TymarkApp.swift
│   │   ├── AppDelegate.swift         # AppKit bridge
│   │   └── Tymark.entitlements
│   └── TymarkMobile/                 # iOS target (v2.0)
├── Packages/
│   ├── TymarkEditor/                 # Core editor engine
│   │   └── Sources/
│   │       ├── TymarkTextView.swift          # Custom NSTextView (TextKit 2)
│   │       ├── TextKit/
│   │       │   ├── TymarkTextContentManager.swift
│   │       │   ├── TymarkTextLayoutManager.swift
│   │       │   ├── TymarkTextLayoutFragment.swift
│   │       │   └── InlineRenderingController.swift
│   │       ├── Cursor/
│   │       │   ├── CursorProximityTracker.swift
│   │       │   └── SelectionManager.swift
│   │       └── Input/
│   │           ├── KeybindingHandler.swift
│   │           ├── SmartPairHandler.swift
│   │           └── SmartListHandler.swift
│   ├── TymarkParser/                 # Markdown parsing engine
│   │   └── Sources/
│   │       ├── MarkdownParser.swift           # Wraps swift-markdown
│   │       ├── IncrementalParser.swift        # Incremental re-parse
│   │       ├── ASTNode.swift
│   │       ├── ASTDiff.swift
│   │       └── ASTToAttributedString.swift    # Rendering pipeline
│   ├── TymarkTheme/                  # Theme engine
│   │   └── Sources/
│   │       ├── Theme.swift
│   │       ├── ThemeManager.swift
│   │       ├── ThemeParser.swift
│   │       └── BuiltInThemes/
│   ├── TymarkWorkspace/              # File/workspace management
│   │   └── Sources/
│   │       ├── WorkspaceManager.swift
│   │       ├── FileTreeProvider.swift
│   │       └── FuzzySearchEngine.swift
│   ├── TymarkSync/                   # iCloud + document management
│   │   └── Sources/
│   │       ├── TymarkDocument.swift           # NSDocument subclass
│   │       ├── SyncStatusTracker.swift
│   │       └── ConflictResolver.swift
│   ├── TymarkExport/                 # Export engine
│   │   └── Sources/
│   │       ├── PDFExporter.swift
│   │       ├── HTMLExporter.swift
│   │       └── DOCXExporter.swift
│   └── TymarkHighlighter/           # Code block syntax highlighting
│       └── Sources/
│           ├── SyntaxHighlighter.swift        # Neon + tree-sitter
│           └── LanguageProvider.swift
├── Extensions/
│   ├── SpotlightImporter/
│   ├── QuickLookPreview/
│   └── ShareExtension/
└── Resources/
    ├── Themes/                       # Bundled theme JSON
    └── DefaultKeybindings.json
```

**External dependencies (minimal, all Swift-native):**

| Package | Purpose | License |
|---------|---------|---------|
| `swift-markdown` (Apple) | Markdown parsing + AST | Apache 2.0 |
| `swift-tree-sitter` | Code block syntax parsing | MIT |
| `Neon` (ChimeHQ) | Syntax highlighting engine | BSD 3-Clause |

No Electron. No web views. No JavaScript. No CocoaPods. Pure Swift.

---

### 13. Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Text view | Custom `NSTextView` (TextKit 2) | Full control over inline rendering. SwiftUI `TextEditor` lacks low-level TextKit 2 hooks |
| Parser | `swift-markdown` | Apple-maintained, spec-compliant CommonMark + GFM, clean Swift AST |
| Code highlighting | Neon + tree-sitter | Incremental, native, TextKit 2 integration |
| Document mgmt | `NSDocument` subclass | Battle-tested iCloud sync, auto-save, versioning, conflict handling |
| Concurrency | Swift Concurrency (`async/await`) | Modern, structured, cancellation support |
| Package mgmt | SPM with static linking | Apple-native, single binary, no runtime loading |
| Min deployment | macOS 14 (Sonoma) | TextKit 2 maturity + sufficient user base |

---

### 14. Rendering Pipeline

```
User Types Character
        |
        v
NSTextView receives edit
        |
        v
Edit Range Computation (which block-level AST node was affected?)
        |
        v
Incremental Re-parse (TymarkParser)
  -> swift-markdown parses only the affected block(s)
        |
        v
AST Diff (compare old subtree vs new subtree)
        |
        v
Attribute Mapping (AST -> NSAttributedString)
  -> attach TymarkRenderingAttribute to each node
        |
        v
Cursor Proximity Check
  -> cursor inside node -> "source mode" (show syntax)
  -> cursor outside node -> "rendered mode" (hide syntax)
        |
        v
TextKit 2 Layout Pass
  -> Custom NSTextLayoutFragment subclasses for images, code blocks, tables
        |
        v
Display (60-120fps via Core Animation)
```

**Critical constraint:** Entire pipeline from keystroke to display must complete within **8ms** to maintain 120fps on ProMotion displays.

---

### 15. Development Roadmap (30 weeks to v1.0)

#### Pre-Development: Proof of Concept (Weeks 1-2)

- TextKit 2 inline rendering of headings, bold, italic
- Validate cursor-proximity toggle works with acceptable performance
- Benchmark render pipeline < 8ms
- **Decision gate:** If TextKit 2 can't support inline rendering, evaluate STTextView

#### Phase 1: Foundation (Weeks 3-8)

- **Wk 3-4:** `TymarkParser` — swift-markdown integration, AST mapping, incremental parse
- **Wk 5-6:** `TymarkEditor` — custom NSTextView, TextKit 2 layout manager, basic inline rendering
- **Wk 7-8:** App shell — SwiftUI structure, document open/save, window management
- **Milestone:** Open `.md` file, see inline-rendered headings/bold/italic/code with cursor toggle

#### Phase 2: Core Features (Weeks 9-16)

- **Wk 9-10:** Complete inline rendering (lists, blockquotes, links, images, tables)
- **Wk 11-12:** `TymarkHighlighter` — Neon + tree-sitter for code blocks
- **Wk 13-14:** `TymarkTheme` — theme engine, 6 built-in themes, custom loading
- **Wk 15-16:** `TymarkWorkspace` — file browser, tabs, quick open, outline
- **Milestone:** Fully functional editor with all markdown elements, themes, workspaces

#### Phase 3: System Integration (Weeks 17-20)

- **Wk 17-18:** `TymarkSync` — NSDocument, iCloud sync, auto-save
- **Wk 19:** Spotlight importer, Quick Look extension
- **Wk 20:** `TymarkExport` — PDF, HTML, DOCX
- **Milestone:** Complete system integration, iCloud sync, Quick Look, export

#### Phase 4: Polish & Beta (Weeks 21-24)

- **Wk 21-22:** Command palette, keybindings, keyboard customization
- **Wk 23:** Performance optimization pass (Instruments profiling)
- **Wk 24:** TestFlight beta (500 testers)

#### Phase 5: Launch (Weeks 25-30)

- **Wk 25-28:** Beta feedback, bug fixes, edge cases
- **Wk 29:** App Store submission, marketing prep
- **Wk 30:** **v1.0 Launch**

---

### 16. Testing Strategy

- **Unit tests (per module):** 300+ parser test cases (CommonMark spec compliance, GFM, edge cases). Theme loading/validation. Fuzzy search scoring. Export output validation.
- **Integration tests:** Editor + Parser (type sequences -> verify attributes). Editor + Theme (switch -> verify colors). Sync (open, edit, save, reopen -> verify integrity).
- **Performance tests:** XCTest benchmarks for keystroke latency, document open time, scroll FPS, memory usage. **No PR merges if benchmarks regress > 10%.**
- **Snapshot tests:** Render markdown to images, compare against golden screenshots. One snapshot per theme per key element.
- **CI/CD:** GitHub Actions, macOS runners. Every PR: unit + integration + performance tests. Nightly: full snapshot suite.

---

### 17. Investment Thesis (VC-Facing)

**The Ask:** $500K seed for 18 months runway (solo founder + 1 hire).

**Why this wins:**

1. **Market timing** — TextKit 2 maturity + SwiftUI multiplatform + Electron fatigue = once-in-a-cycle opportunity
2. **Technical moat** — Native performance is architecturally impossible for Electron competitors to match
3. **Proven model** — $29 one-time purchase is proven in Mac productivity (Things, Fantastical, Pixelmator)
4. **Expansion path** — macOS -> iOS -> iPadOS -> visionOS from shared SwiftUI codebase. Each platform = 2-3x TAM
5. **Exit potential** — Acquisition target for Apple, Automattic, or Notion/Obsidian. Comparable: Fantastical, Bear, Things ($10M+/yr)

**Use of funds:** 60% Engineering, 15% Design, 15% Marketing, 10% Infrastructure.

**Milestones for next raise:** v1.0 launched, 50K downloads, 4K Pro purchases ($116K revenue). Series A at $2-3M to fund iOS + plugin ecosystem.

---

### 18. Verification Plan

1. **POC validation (Week 2):** Build standalone prototype — inline render headings + bold in TextKit 2 NSTextView. Measure: render < 8ms, cursor toggle works.
2. **Parser correctness:** Run against full CommonMark spec test suite (652 examples). Target: 100% pass rate.
3. **Performance regression CI:** Automated XCTest benchmarks on every PR. Gate: no regression > 10%.
4. **Beta testing:** 500 TestFlight users. Track: crash-free sessions (target 99.5%), NPS (target 50+).
5. **Launch validation:** App Store review pass, 4.5+ rating in first 100 reviews.
