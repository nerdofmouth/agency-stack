# AgencyStack custom jonathan.zsh-theme (based on Oh My Zsh jonathan)
# https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/jonathan.zsh-theme

# AgencyStack ANSI doodle/branding
local agency_stack="%{$fg_bold[magenta]%}⧉ AgencyStack ⧉%{$reset_color%} "

# Original jonathan theme prompt
PROMPT='${agency_stack}%{$fg[cyan]%}%n@%m %{$fg[green]%}%~ %{$reset_color%}$ '

# Git info (same as original)
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[red]%}git:(%{$fg[magenta]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}%{$fg[red]%})%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[yellow]%}*"
ZSH_THEME_GIT_PROMPT_CLEAN=""
