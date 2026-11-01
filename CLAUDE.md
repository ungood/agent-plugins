# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. This is a long line to test comrak.

## Project Overview

This repository is a Claude Code plugin marketplace containing a personal collection of plugins.

## Structure

- `.claude-plugin/` - Marketplace configuration
  - `marketplace.json` - Plugin marketplace manifest
- `plugins/` - Individual plugin directories

## Checks

Run `mise run check` before committing, and `mise run fix` to apply formatting. The checks include the fleet [standards](https://github.com/ungood/standards).

## Documentation

1. [Commands](docs/commands.md)
2. [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)
3. [Marketplace](https://code.claude.com/docs/en/marketplace)
4. [Settings](https://code.claude.com/docs/en/settings)

## Tenets

- Create the simplest plugin structure as you can.
- Do not add author field to plugin manifests when it is redundant with marketplace.json
- Do not add email address.
