#!/bin/bash
cd "`dirname $0`"
while true; do
    (
      ./node_modules/.bin/coffee \
        --nodejs --max-old-space-size=${MAX_OLD_SPACE_SIZE:-1024} \
        statistics-worker.coffee \
      || sleep 4
    )
    sleep 1
done
