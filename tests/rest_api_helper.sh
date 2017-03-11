#!/bin/bash

if [ "x$CLEANUP" = "x1" ]; then
    echo "Cleaning up database"
    docker-compose stop
    docker-compose rm -vf
    docker-compose up -d

    sleep 2
    echo "Initializing couch views"
    docker-compose run -e COUCH_SYNC=1 app node index.js | ./node_modules/.bin/bunyan
fi

set -e

curlbin=`which curl`
function curl() {
    if [ "x$RECREATE" = "x1" ]; then
      test -e docker-compose.yml && docker-compose up --no-deps --no-recreate -d || true
    fi
    $curlbin -s -H 'Content-type: application/json' "$@" > .curloutput.txt
    cat .curloutput.txt | json_pp > .testoutput.txt
    # testoutput
}

function json_pp() {
    xargs -0 node -e "console.log(JSON.stringify(JSON.parse(process.argv[1]), null, 2))"
}

function printOutput() {
    cat .testoutput.txt
}

function outputIncludes() {
    cat .testoutput.txt | grep "$@" > /dev/null || echo "      FAIL"
    cat .testoutput.txt | grep "$@" > /dev/null || (printOutput && false)
}

function outputExcludes() {
    cat .testoutput.txt | grep "$@" > /dev/null || return 0
    echo "      FAIL" && false
}

function it() {
    echo "    - $@"
}

function initializeTestUser() {
    echo "    - [initializing test user]" >&2
    curl $DIRECTORY_URL/directory/v1/users -d '{
        "id":"'${TEST_USER_ID}'",
        "password":"'${TEST_PASSWORD}'",
        "secret":"'$API_SECRET'",
        "aliases":[
            {"type":"name","public":true,"value":"'${TEST_USERNAME}'"},
            {"type":"tag","public":true,"value":"'${TEST_TAG}'"},
            {"type":"email","public":false,"value":"'${TEST_EMAIL}'"}
        ]
    }'
    curl $DIRECTORY_URL/directory/v1/users/auth -d '{
        "id":"'${TEST_USER_ID}'",
        "password":"'${TEST_PASSWORD}'"
    }'
    outputIncludes "token" || echo "Failed to authenticate test user"
    outputIncludes "token"

    # output the auth token
    AUTH_TOKEN=`printOutput | grep token | cut -d\" -f4`
    echo "      [auth token: $AUTH_TOKEN]" >&2
    echo $AUTH_TOKEN
}
