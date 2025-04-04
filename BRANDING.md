# AgencyStack Branding Guidelines

## 📦 Assembled by AgencyStack – Powered by Nerd of Mouth

This document outlines the branding system implemented within the AgencyStack ecosystem.

## Core Branding Elements

### Brand Architecture

- **Product Name**: AgencyStack
- **Creator**: Nerd of Mouth
- **Slogan**: Deploy Smart. Speak Nerd.
- **Homepage**: https://stack.nerdofmouth.com
- **Support**: support@nerdofmouth.com

### Taglines (Rotating)

AgencyStack displays a rotating set of taglines across various screens and interfaces:

1. "Run your agency. Reclaim your agency."
2. "Tools for freedom, proof of power."
3. "The Agency Project: Metal + Meaning."
4. "Don't just deploy. Declare independence."
5. "Freedom starts with a shell prompt."
6. "From Zero to Sovereign."
7. "CLI-tested. Compliance-detested."
8. "An agency stack with an agenda: yours."

## Implementation Details

### Branding Source File

The primary branding data is stored in:
- **branding.json**: Central source of truth for branding elements

### Branding Scripts

The branding system is implemented through the following scripts:

- **agency_branding.sh**: Core branding utilities
  - `random_tagline`: Displays a random tagline
  - `display_banner`: Shows full ASCII art banner with tagline
  - `display_header`: Shows a compact header with tagline

- **nerdy_quote.sh**: Displays random nerdy quotes
  - Usage: `make talknerdy`

- **system_performance.sh**: Displays system stats with branding
  - Usage: `make rootofmouth`

### Integration Points

The branding system is integrated at the following touchpoints:

1. **Makefile**: 
   - Help screens
   - Custom commands (`talknerdy`, `rootofmouth`)
   - System information displays

2. **Installation Scripts**:
   - Header displays
   - Completion messages
   - Progress updates

3. **Client Setup**:
   - Bootstrap welcome
   - Completion confirmations

## Usage Examples

### Display Random Tagline

```bash
source scripts/agency_branding.sh && random_tagline
```

### Display Full Banner

```bash
scripts/agency_branding.sh banner
```

### Add to New Scripts

Add the following code to any new script:

```bash
SCRIPT_PATH="$(dirname "$(realpath "$0")")"
if [ -f "$SCRIPT_PATH/../agency_branding.sh" ]; then
  source "$SCRIPT_PATH/../agency_branding.sh" && random_tagline
fi
```

## Easter Eggs

The system includes several easter eggs:

- `make talknerdy`: Displays random nerdy quotes
- `make rootofmouth`: Shows detailed system statistics

## Philosophy

AgencyStack is built on the principles of sovereignty, agency, and freedom. The branding reflects this ethos through strong, independent messaging that empowers users to take control of their digital infrastructure.

_"Proof of work. Test of will. Tools for freedom."_
