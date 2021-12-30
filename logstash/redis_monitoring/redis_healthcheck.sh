#!/bin/bash

############################################################################################################
#
# Prerequisite: apt install jq
# 
#
#
#
############################################################################################################


health_check(){
  for ip in "$@"; do
    UNAVAILABLE=$(redis-cli --cluster call $ip info stats -a 1234 2>&1 > /dev/null)

    AVAILABLE=$(redis-cli --cluster call $ip info stats -a 1234 2> /dev/null | grep --perl-regexp '[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}:[0-9]{4,5}' --only-matching)

    UNAVAILABLE=$(echo $UNAVAILABLE | grep --perl-regexp '[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}:[0-9]{4,5}' --only-matching)
    if [ -z "$AVAILABLE" ]; then
      continue
    else
      echo '{ "available": "'$AVAILABLE'", "unavailable": "'$UNAVAILABLE'"}' | jq
      break
    fi
  done
}
SERVER_LIST=($(cat redis_server_list.txt))
health_check ${SERVER_LIST[@]}

NUMBER_OF_SERVER=${#SERVER_LIST[@]}