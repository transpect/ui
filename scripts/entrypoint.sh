#!/bin/bash

set -u

/opt/basex/bin/basex -c "XQUERY import module namespace ns = 'http://le-tex.de/namespaces' at '/opt/basex/install/transpectui/namespaces.xqm'; ns:install()" >> /opt/basex/install.txt

./bin/basexhttp -h 8000 -s 8010
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
