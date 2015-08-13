#!/bin/bash

set -e
cd "`dirname $0`"

if [[ -z "$WORKER_INTERVAL" ]]; then
    WORKER_INTERVAL=1
fi

# Launch 1 worker per second.
#
# If worker can't finish its job under N seconds, 2 workers will run in parallel.
# This is cheap autoscaling.
while true; do
    # echo ./node_modules/.bin/coffee src/push-api/sender-cli.coffee
    ./node_modules/.bin/coffee statistics-worker.coffee
    sleep $WORKER_INTERVAL
done
