#!/bin/bash

set -u

./bin/basexhttp -h 8000 -s 8010

#sleep 2

#WEBAPP_DIR="/opt/basex/webapp/transpectui"
#LOG_FILE="/opt/basex/install.log"
#INTERVAL=1

#declare -A FILE_TIMES
#log() {
#    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
#}
#
#echo "Watcher started"
#
#while true; do
#
#    while IFS= read -r -d '' file; do
#        mtime=$(stat -c '%Y' "$file")
#
#        if [[ "${FILE_TIMES[$file]:-}" != "$mtime" ]]; then
#            FILE_TIMES[$file]=$mtime
#
#            log "Installing $file"
#
#            if bin/basex -c "REPO INSTALL $file" >> "$LOG_FILE" 2>&1; then
#                log "SUCCESS $file"
#            else
#                log "FAILED $file"
#            fi
#        fi
#
#    done < <(
#        find "$WEBAPP_DIR" -type f \
#            \( -name '*.xqm' -o -name '*.xar' \) \
#            -print0
#    )
#
#    sleep "$INTERVAL"
#done
