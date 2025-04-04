#!/bin/bash

# motto.sh – Tagline randomizer for Launchbox by NerdofMouth™

MOTTOS=(
  "Launchbox: The Nerve Center of Your Revolution."
  "Launchbox: So Powerful, We’re Already on a Watchlist."
  "Launchbox: Eat Latency. Shit Metrics. Love Freedom."
  "Brains, Metal, and Sovereignty. In One Click."
  "Built for Pirates. Banned by Empires."
  "Launch Smarter. Build Louder. Ship Ruthless."
  "Not SaaS. Not IaaS. This is Guerrilla Infrastructure."
  "Eat Brains. Ship Faster. Sleep Never."
  "Launchbox: One Stack to Rule Your Work."
  "Built to Serve Builders, Not Stakeholders."
  "Launchbox: Stack Sovereignty in Every Byte."
  "Launchbox: Move at the Speed of Truth."
  "Launchbox: Built for the Infinite Game."
  "Deploy with Teeth. Maintain with Malice."
  "Launchbox: Infrastructure for Dangerous Ideas."
)



function random_motto() {
  SIZE=${#MOTTOS[@]}
  INDEX=$((RANDOM % SIZE))
  echo -e "\033[1;35m${MOTTOS[$INDEX]}\033[0m"
}

# Run by default if this is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  random_motto
fi
