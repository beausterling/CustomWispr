# Contributing to CustomWispr

Thanks for your interest in contributing! This is a small project and contributions are welcome.

## Getting Started

1. Fork the repo and clone it locally
2. Follow the [Installation](README.md#installation) and [Setup](README.md#setup) instructions to get the app running
3. Make your changes
4. Test by building with `./build-arm64.sh` (or `./build.sh` for Intel) and running the app
5. Open a pull request

## Reporting Bugs

Open an issue using the **Bug Report** template. Include:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Your macOS version and Mac architecture (Intel or Apple Silicon)

## Suggesting Features

Open an issue using the **Feature Request** template. Describe the problem you're trying to solve and your proposed solution.

## Pull Requests

- Keep changes focused — one feature or fix per PR
- Test that the app builds and runs before submitting
- Describe what your change does and why in the PR description

## Code Style

- Follow the existing patterns in the codebase
- Use the `log()` function for all logging (not `print` or `NSLog`)
- Keep it simple — this is a lightweight app with no external dependencies

## Questions?

Open an issue and ask. There are no dumb questions.
