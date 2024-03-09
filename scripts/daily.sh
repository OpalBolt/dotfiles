#!/bin/bash

# Source other bash scripts
. ./log.sh

# Setting variables
today=$(date +"%Y%m%d")
dailypath="$SECOND_BRAIN/dailynotes"

# A bash script to create daily notes
# What i need this script to do:
# - Run with no arguments
# - take todays day and see if file already exists
#   - If not exists, create file and drop me into editor (Nvim)
#   - If file exist, crop me into editor (nvim)
# - If new file is created, copy todo's from last daily note into new one.
# Running examples:
# daily


get_newest_daily(){
    elog "Fetching newest daily file"
    edebug "loading array into filearray"
    filearray=($("ls" -r $dailypath))
    edebug "defineing newest_daily to be: ${filearray[1]}"
    newest_daily=${filearray[1]}
    edebug "newest_daily: $newest_daily"
}

open_file() {
  if [ -e "$dailypath/$today.md" ]; then
      edebug "open's op today.md"
      nvim "$dailypath/$today.md"
  else
      edebug "start function to get newest daily"
      get_newest_daily
      # Sets up timestamp to use later
      timestamp=$(date +"%Y-%m-%d")
     
      edebug "cd into dailypath"
      # CD into daily path
      cd "$dailypath" || exit
      edebug "current directory $(pwd)"
      
      edebug "Create $today.md file"
      # Create daily file
      touch "$today.md"
      
      edebug "fill out $today.md with default infomation"
      # input all content into today that is needed
      tee "$today.md" << EOF
---
date: $(date +"%Y-%m-%d")
tag:
- daily
---

## Agenda

## Todo

## Notes
$(grep -Pi '^-\s\[(?!x\])(.)\]' $newest_daily)

## links
EOF
    edebug "fix all open tasks in newest_daily"
    sed -i 's/\[ \]/\[X\]/g' $newest_daily

    edebug "open up $today.md with neovim"
    nvim "$today.md"

    fi
}
edebug "trying to run open_file function"
open_file
