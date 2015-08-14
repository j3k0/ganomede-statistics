#!/bin/bash
cd "`dirname $0`"
while true; do
    (./node_modules/.bin/coffee statistics-worker.coffee || sleep 5)
done
