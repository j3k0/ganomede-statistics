#!/bin/bash

BASE_URL="${BASE_URL:-http://localhost:8000}"
PREFIX="${BASE_URL}/statistics/v1"
API_SECRET=${API_SECRET:-1234}

DIRECTORY_URL="${DIRECTORY_PORT_8000_TCP_PROTOCOL:-http}://${DIRECTORY_PORT_8000_TCP_ADDR:-directory}:${DIRECTORY_PORT_8000_TCP_PORT:-8000}"
COORDINATOR_URL="${COORDINATOR_PORT_8000_TCP_PROTOCOL:-http}://${COORDINATOR_PORT_8000_TCP_ADDR:-directory}:${COORDINATOR_PORT_8000_TCP_PORT:-8000}"

TEST_USER_ID="jeko"
TEST_PASSWORD="password12345678"
TEST_USERNAME="IamJeko"
TEST_TAG="iamjeko"
TEST_EMAIL="jeko@free.fr"

. `dirname $0`/rest_api_helper.sh

# AUTH_TOKEN=`initializeTestUser`

# Basics
it 'responds to /ping'
    curl $PREFIX/ping/ruok
    outputIncludes ruok

it 'responds to /about'
    curl $PREFIX/about
    outputIncludes '"type": "statistics"'

# Add metadata
#TEST_PUBLIC_KEY=testpublic
#TEST_PUBLIC_VALUE=$RANDOM
#it 'sets public metadata'
#    curl $PREFIX/auth/$AUTH_TOKEN/$TEST_PUBLIC_KEY -d '{"value":"'${TEST_PUBLIC_VALUE}'"}'
#    outputIncludes '{'
#
#it 'reads public metadata by user id'
#    curl $PREFIX/$TEST_USER_ID/$TEST_PUBLIC_KEY
#    outputIncludes $TEST_PUBLIC_VALUE
#
#it 'reads public metadata by auth token'
#    curl $PREFIX/auth/$AUTH_TOKEN/$TEST_PUBLIC_KEY
#    outputIncludes $TEST_PUBLIC_VALUE
#
#TEST_PROTECTED_KEY=testprotected
#TEST_PROTECTED_VALUE=$RANDOM
#it 'sets protected metadata'
#    curl $PREFIX/auth/$AUTH_TOKEN/$TEST_PROTECTED_KEY -d '{"value":"'${TEST_PROTECTED_VALUE}'"}'
#    outputIncludes '{'
#
#it 'reads protected metadata by auth token'
#    curl $PREFIX/auth/$AUTH_TOKEN/$TEST_PROTECTED_KEY
#    outputIncludes $TEST_PROTECTED_VALUE
#
#it 'refuses to read protected metadata by user id'
#    curl $PREFIX/$TEST_USER_ID/$TEST_PUBLIC_KEY
#    outputExcludes $TEST_PROTECTED_VALUE
