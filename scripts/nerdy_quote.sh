#!/bin/bash
# nerdy_quote.sh - Random nerdy quotes for AgencyStack by Nerd of Mouth
# https://stack.nerdofmouth.com

# Colors for output
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Array of nerdy quotes
quotes=(
  "There are 10 types of people in the world: those who understand binary, and those who don't."
  "If at first you don't succeed; call it version 1.0."
  "My code doesn't work, I have no idea why. My code works, I have no idea why."
  "It's not a bug – it's an undocumented feature."
  "UNIX is user friendly. It's just very particular about who its friends are."
  "Measuring programming progress by lines of code is like measuring aircraft building progress by weight."
  "The best performance improvement is the transition from the nonworking state to the working state."
  "The best thing about a boolean is even if you are wrong, you are only off by a bit."
  "Software and cathedrals are much the same – first we build them, then we pray."
  "Always code as if the guy who ends up maintaining your code will be a violent psychopath who knows where you live."
  "Programming is like sex: one mistake and you have to support it for the rest of your life."
  "Walking on water and developing software from a specification are easy if both are frozen."
  "Debugging is twice as hard as writing the code in the first place. Therefore, if you write the code as cleverly as possible, you are, by definition, not smart enough to debug it."
  "Copy-and-Paste was programmed by programmers for programmers actually."
  "First, solve the problem. Then, write the code."
  "It's harder to read code than to write it."
  "It's not a bug. It's a feature."
  "The difference between theory and practice is greater in practice than in theory."
  "Be nice to nerds. Chances are you'll end up working for one."
  "Artificial intelligence is no match for natural stupidity."
  "I would love to change the world, but they won't give me the source code."
)

# Get a random quote
random_quote() {
  local index=$((RANDOM % ${#quotes[@]}))
  echo -e "${CYAN}${BOLD}\"${quotes[$index]}\"${NC}"
  echo -e "${YELLOW}— Nerd of Mouth${NC}"
}

# Run if script called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  random_quote
fi
