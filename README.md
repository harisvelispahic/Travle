# Travle Documentation Package

Generated 2026-07-09, finalized 2026-07-10 (reconciliation rounds 1–2 complete) from: the approved topic application (Prijava), the official course specification (Upute za izradu seminarskog rada 2025/26), the previous draft documentation, and inspection of the course template repo (`rsII_exam_template_2025_26`).

| File                                               | Purpose                                                                                                                                                                                                               |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `00-ANALYSIS-AND-OPEN-QUESTIONS.md`                | Every inconsistency/gap found across the source documents, its resolution, and the full decision log — reconciliation record.                                                                                         |
| `TRAVLE-SPECIFICATION.md`                          | Consolidated single source of truth: what gets built. Supersedes the old `Travle_Project_Documentation_EN.md`.                                                                                                        |
| `claude-context/CLAUDE.md`                         | Entry point for the Claude agent: project facts, standing rules, read order, definition of done. Drop the `claude-context/` folder into the repo root (rename to `.claude/` or keep as-is and point CLAUDE.md at it). |
| `claude-context/01-course-constraints.md`          | Full extraction of the course's hard rules as checklists — including Dodatak A ("suggested things"), treated as mandatory.                                                                                            |
| `claude-context/02-architecture-and-code-rules.md` | Template adoption plan, exception middleware design, per-entity EF configurations, solution + Flutter structure, config management.                                                                                   |
| `claude-context/03-database-design.md`             | Entities, reference tables, delete behaviors, indexes, the capacity/concurrency contract, seed plan.                                                                                                                  |
| `claude-context/04-recommender-spec.md`            | ML.NET verdict, signals, scoring formula, explanations, storage options A/B/C — also the seed for the mandatory `recommender-dokumentacija.md`.                                                                       |
| `claude-context/05-implementation-roadmap.md`      | 13 dependency-ordered phases, each with a definition of done.                                                                                                                                                         |
| `claude-context/06-template-adoption-guide.md`     | Step-by-step eCommerce→Travle rename, purge/keep lists, verification gate.                                                                                                                                            |
| `claude-context/07-mobile-app-structure.md`        | Text wireframes: bottom nav, every mobile screen, controls and flows.                                                                                                                                                 |
| `claude-context/08-ui-design-system.md`            | Design tokens (palette placeholder), Flutter theming, the shared `travle_ui` package, widget catalogue.                                                                                                               |
| `RECOMMENDER-EXPLAINED-personal-notes.md`          | **Personal learning notes for Haris — do NOT feed to the agent.** Long-form explanation of the recommender with a worked example.                                                                                     |

Suggested repo placement:

```
travle/
├── CLAUDE.md                      ← from claude-context/CLAUDE.md
├── docs/
│   ├── TRAVLE-SPECIFICATION.md
│   ├── 00-ANALYSIS-AND-OPEN-QUESTIONS.md
│   └── context/01..08-*.md        ← referenced by CLAUDE.md
└── recommender-dokumentacija.md   ← derived from 04, must ship in repo root
```

All decisions are final — no open items. `00-ANALYSIS-AND-OPEN-QUESTIONS.md` is the permanent reconciliation record; its §3 defines the stretch features (post-Phase-11 only). UI language is English; all times are UTC.
