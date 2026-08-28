# Contributing to DualSenseT

Thanks for your interest in contributing! DualSenseT is a solo-built, open-source project and all help is appreciated — whether it's bug reports, feature ideas, or pull requests.

---

## 🐛 Reporting Bugs

Before opening an issue:
- Check the [existing issues](https://github.com/DegenerateUSER/DualsenseT/issues) to avoid duplicates
- Make sure you're on macOS 13.0+ with a supported controller

When filing a bug, use the **Bug Report** template and include:
- Your macOS version
- Controller model (DualSense / DualSense Edge) and connection type (BT / USB)
- Steps to reproduce
- What you expected vs. what happened
- Console logs if relevant (open **Console.app** and filter by `DualSenseT`)

---

## 💡 Requesting Features

Open a [GitHub Discussion](https://github.com/DegenerateUSER/DualsenseT/discussions) or use the **Feature Request** issue template. Describe the use case clearly — what problem does it solve?

---

## 🔧 Submitting Pull Requests

1. **Fork** the repo and create a branch: `git checkout -b feat/your-feature`
2. Make your changes. Keep commits focused and atomic.
3. Run the test suite before pushing: `./build.sh test`
4. Open a PR against `main`. Describe what you changed and why.

### Code Style
- Swift standard conventions (4-space indent, `camelCase` for variables, `PascalCase` for types)
- No external dependencies — this is intentionally zero-dependency
- If you add a new feature, add tests in `Tests/tests.swift`

### Areas Where Help is Especially Welcome
- Screenshots / screen recordings for the README
- Testing on additional macOS versions
- DualSense Edge-specific feature support
- Additional UDP protocol game compatibility testing
- Localization

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
