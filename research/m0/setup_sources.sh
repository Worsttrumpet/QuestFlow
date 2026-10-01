#!/bin/sh
# M0: fetch the exact commits that were analysed (shallow). Run from an empty working directory.
set -e
get() { # name url sha
  [ -d "$1" ] && return 0
  git init -q "$1" && git -C "$1" remote add origin "$2"
  git -C "$1" fetch -q --depth 1 origin "$3" && git -C "$1" checkout -q FETCH_HEAD
}
get AllTheThings   https://github.com/ATTWoWAddon/AllTheThings.git        8e25511677df4ea5c3d0322009eafc18f203ffd3
get ForeverGuide   https://github.com/RevoltLive85/ForeverGuide.git       561023695a0364024e290f2d39b385d24d6cfad3
get lodestar       https://github.com/danielcosta42/lodestar.git          8964d0ca325919ce33e9c40693ad204ee9203e0c
get QuestieDB      https://github.com/Questie/QuestieDB.git               baa0998d49695c70a1fb8fec559fa9169e9adf33
