#!/bin/bash

# motto.sh – Tagline randomizer for AgencyStack by NerdofMouth™

mottos=(
  "AgencyStack: The Nerve Center of Your Revolution."
  "AgencyStack: So Powerful, We're Already on a Watchlist."
  "AgencyStack: Eat Latency. Shit Metrics. Love Freedom."
  "AgencyStack: Digital Sovereignty in a Box."
  "AgencyStack: Bringing Promise to a Broken Stack."
  "AgencyStack: For When SaaS Becomes a Four-Letter Word."
  "AgencyStack: Handcrafted by the Unaligned."
  "AgencyStack: One Stack to Rule Your Work."
  "AgencyStack: Weapons-Grade Infrastructure."
  "AgencyStack: Stack Sovereignty in Every Byte."
  "AgencyStack: Move at the Speed of Truth."
  "AgencyStack: Built for the Infinite Game."
  "AgencyStack: Freedom for Full-Stack Thinkers."
  "AgencyStack: Infrastructure for Dangerous Ideas."
  "AgencyStack: Run your agency. Reclaim your agency."
)



function random_motto() {
  SIZE=${#mottos[@]}
  INDEX=$((RANDOM % SIZE))
  echo -e "\033[1;35m${mottos[$INDEX]}\033[0m"
}

# Run by default if this is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  random_motto
fi
