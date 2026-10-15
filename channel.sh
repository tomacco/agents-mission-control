# Names for one install of Agents Mission Control, sourced by build.sh, install.sh and uninstall.sh.
# AMC_CHANNEL unset is the real install; any other value (e.g. test) is a separate copy macOS sees as
# another app, with its own folder, socket, LaunchAgents and Full Disk Access grant.
CH=${AMC_CHANNEL:-}
SUF=${CH:+.$CH}
ID=co.tomac.amc$SUF
APPNAME="Agents Mission Control${CH:+ ($CH)}"
APPFILE=AgentsMissionControl${CH:+-$CH}.app
AMC_HOME=$HOME/.amc${CH:+-$CH}
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
export AMC_SOCKET=$AMC_HOME/amc.sock AMC_FLAG=$AMC_HOME/hands-off
