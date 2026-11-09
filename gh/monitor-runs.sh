#!/bin/zsh
set -eu

# MONITOR RUNS
# Poll GitHub Actions runs for one commit and report their status.
# Usage: monitor-runs.sh [-b BRANCH] [-s SHA] [-i SECONDS]
#                        [-n NAME] [-1]
#   -b BRANCH   branch to watch (default main)
#   -s SHA      commit prefix to watch (default: origin/BRANCH HEAD)
#   -i SECONDS  poll interval (default 180)
#   -n NAME     only runs whose name starts with NAME (default "Test ")
#   -1          poll once and exit
# Each poll is one 'gh run list' call.  After an API error the
# interval doubles, to stay clear of the rate limit.
# Output goes to tmp-monitor.log (append) and tmp-monitor.fifo.
# Read it with:  tail -f tmp-monitor.log
#           or:  cat tmp-monitor.fifo

zparseopts -D -E b:=B s:=S i:=I n:=N 1=O
BR=main
SHA=""
SECS=180
NAME="Test "
ONCE=0
(( ${#B} )) && BR=${B[2]}
(( ${#S} )) && SHA=${S[2]}
(( ${#I} )) && SECS=${I[2]}
(( ${#N} )) && NAME=${N[2]}
(( ${#O} )) && ONCE=1

LOG=$PWD/tmp-monitor.log
FIFO=$PWD/tmp-monitor.fifo
[[ -p $FIFO ]] || mkfifo $FIFO
# Open read-write so writes never block waiting for a reader.
exec 3<>$FIFO

emit()
{
  local LINE="$(date -u +%H:%M:%S) $*"
  print -r -- "$LINE" >> $LOG
  print -r -- "$LINE" >&3
}

git fetch origin $BR -q
if [[ -z $SHA ]] {
  SHA=$( git rev-parse --short=7 origin/$BR )
}
emit "watching $BR commit $SHA every ${SECS}s"

JQ=".[] | select(.headSha[0:${#SHA}]==\"$SHA\" and"
JQ+=" (.name|startswith(\"$NAME\"))) | \"\(.databaseId)"
JQ+=" \(.name) \(.status) \(.conclusion // \"\")\""

while true
do
  if ROWS=$( gh run list --branch $BR --limit 15 \
             --json databaseId,name,headSha,status,conclusion \
             --jq "$JQ" 2>&1 ) {
    SECS_NOW=$SECS
  } else {
    emit "gh error, backing off: $ROWS"
    SECS_NOW=$(( SECS * 2 ))
    ROWS=""
  }
  if [[ -z $ROWS ]] {
    emit "no matching runs yet"
  } else {
    print -r -- "$ROWS" | while read -r R
    do
      emit "$R"
    done
  }
  if (( ONCE )) break
  if [[ -n $ROWS ]] && ! print -r -- "$ROWS" | \
       grep -q -E '(queued|in_progress|waiting)'
  then
    emit "DONE"
    break
  fi
  sleep $SECS_NOW
done

exec 3>&-
