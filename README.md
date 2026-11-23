<div align="center">

# ArrowKnots

### Procedural Topological Logic Puzzle Game

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![CustomPainter](https://img.shields.io/badge/Graphics-CustomPainter-black?style=for-the-badge&logo=flutter&logoColor=white)](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-00599C?style=for-the-badge&logo=flutter&logoColor=white)](https://riverpod.dev)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-16--Node_Matrix-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](.github/workflows/generate_levels.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

</div>

---

## Overview

ArrowKnots is an algorithmic topological puzzle game where players solve and untangle intersecting arrow paths and knot networks. Engineered for infinite replayability, it uses mathematical level generators to create levels with progressive difficulty curves rather than storing massive static asset files.

---

## Key Features

* **Infinite Procedural Levels:** Procedural algorithm generates unique topological layouts across multiple difficulty tiers without ballooning app size.
* **Hardware Accelerated Graphics:** Custom canvas rendering running at fluid 60 and 120 FPS using targeted repaint boundaries to eliminate animation stutter.
* **Responsive Gesture Interaction:** Touch gesture handling supporting arrow path tracing, knot rotation, and dynamic hint solving.
* **Multi Step History:** StateNotifier architecture managing multi step undo and redo histories without memory bloat.
* **Distributed CI/CD Generation:** Distributed 16 runner GitHub Actions matrix pipeline running headless Dart generators to compute and merge level packs in parallel.

---

## Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter 3.x (Android & Cross Platform) |
| **Language** | Dart |
| **Graphics Engine** | Flutter CustomPainter & Canvas API |
| **State Management** | Riverpod & StateNotifier |
| **Local Storage** | ObjectBox / SharedPreferences |
| **CI/CD Automation** | GitHub Actions 16-Node Concurrent Matrix Runner |

---

## Architecture

The codebase follows Clean Architecture principles:

```text
lib/
├── core/                  # Game constants, audio helpers, and theme configuration
├── data/                  # Level datasets, shape templates, and progress service
├── domain/                # Grid models, arrow path algorithms, and collision logic
├── presentation/          # Custom canvas painters, game screen, and level select UI
└── main.dart              # Game initialization and state bindings
```

---

## Engineering Highlights

### 16-Runner Distributed Matrix Automation
Computing path crossing validation algorithms on mobile devices caused initial frame drops. The project offloaded generation to a distributed GitHub Actions matrix pipeline (`generate_levels.yml`) running across 16 parallel Ubuntu runner machines. Each machine computes a level chunk in parallel using `dart run tool/generate_packs.dart`, and a downstream merge job compiles and deploys the verified level pack.

### Targeted Repaint Boundaries
To maintain smooth 120 FPS on high refresh displays, dynamic arrow animations are isolated inside dedicated `RepaintBoundary` widgets. This ensures static grid elements and UI overlays are never re-rasterized during motion.

---

## Getting Started

```bash
# Clone the repository
git clone https://github.com/qimar/arrowknots.git

# Enter project directory
cd arrowknots

# Install dependencies
flutter pub get

# Launch the game
flutter run
```

---

## License

Distributed under the MIT License. See `LICENSE` for details.
