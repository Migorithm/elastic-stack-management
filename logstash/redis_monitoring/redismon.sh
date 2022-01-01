#!/bin/bash

############################################################################################################
# This script is to sequentially issue query against redis servers and check the following: 
# 1.cluster health
# 2.Cluster topology
# 2.Performance
#
# Main idea is with this script, we'll be able to extract data in JSON format and send this to 
# Logstash 
# Prerequisite: jq, redis-cli
# 
#
#
#
############################################################################################################

help(){
  echo -e "  redismon.sh [OPTIONS] [arg]
    -f, --file [path] Path to the file that lists servers.  (Required)
    -p, --perf        Enable to monitor current performance.
    -c, --cluster     Check available/unavailable node in a cluster.
    -a, --auth        Take masterauth to get access to cluster. (Required if exists)
    -t, --top         Represent Topology.
  "
}

params(){
  if [[ "$#" -eq 0 ]];then
    help
    exit 1
  else 
    while [[ $# -gt 0 ]]; do
      if [[ "${1,,}" == "-f" ]] || [[ "${1,,}" == "--file" ]]; then
        shift
        FILE_PATH=$1
        #File path Validation
        if [[ $FILE_PATH =~ ^[-] ]]; then
          echo -e "
  [ERROR] Invalid file path."
          help
          exit 1
        elif [[ "$FILE_PATH" == "" ]]; then
          echo -e "
  [ERROR] File path must be given"
          help
          exit 1
        fi
        if ! [[ -f $FILE_PATH ]]; then
          echo -e "
  [ERROR] No such file: $FILE_PATH "
          echo "Program exists..."
          exit 1
        fi
        shift
      elif [[ "${1,,}" == "-p" ]] || [[ "${1,,}" == "--perf" ]]; then
        PERF_CHECK="true"
        shift
      elif [[ "${1,,}" == "-c" ]] || [[ "${1,,}" == "--cluster" ]]; then
        HEALTH_CHECK="true"
        shift
      elif [[ "${1,,}" == "-t" ]] || [[ "${1,,}" == "--top" ]]; then
        TOPOLOGY_CHECK="true"
        shift  
      elif [[ "${1,,}" == "-a" ]] || [[ "${1,,}" == "--auth" ]]; then
        shift
        MASTERAUTH=$1
        if [[ $MASTERAUTH =~ ^[-] ]]; then
          echo -e "[ERROR] Invalid auth."
          help
          exit 1
        fi
        shift  
      else
        help
        exit 0 
      fi
    done
  fi

}

perf_check(){
  for node in "$@"; do
    #masterauth validation
    if [[ -z $(redis-cli -h $node -a $MASTERAUTH ping 2> /dev/null) ]]; then
      echo -e "
  [ERROR] Invalid masterauth : (redacted)"
      echo -e "  Program exists..."
      exit 1
    fi
    UNAVAILABLE=$(redis-cli --cluster call "$node" info stats -a 1234 2>&1 > /dev/null)
    AVAILABLE=$(redis-cli --cluster call "$node" info stats -a 1234 2> /dev/null | grep --perl-regexp '[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}:[0-9]{4,5}' --only-matching)
    UNAVAILABLE=$(echo $UNAVAILABLE | grep --perl-regexp '[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}:[0-9]{4,5}' --only-matching)
    if [ -z "$AVAILABLE" ]; then
      continue
    else
      RETURN=$(echo '{ "available": "'"$AVAILABLE"'", "unavailable": "'$UNAVAILABLE'"}')
      break
    fi
  done
  if [[ -z "$RETURN" ]]; then
     RETURN='{ "unavailable": "'"$@"'" }'
  fi
  echo $RETURN
}


health_check(){
  UNAVAILABLE=()
  AVAILABLE=()
  while [[ $# -gt 0 ]]; do
    PING=$(redis-cli -h $1 -p $2 -a $MASTERAUTH ping 2> /dev/null)
    if [[ -z $PING ]]; then
      echo -e "  [FAIL] Connection refused : $1:$2"
      UNAVAILABLE+=("$1:$2")
      shift
      shift
    else
      echo -e "  [SUCCESS] Connection refused : $1:$2"
      AVAILABLE+=("$1:$2")
      shift
      shift
    fi
  done
  #topology 
  for node in ${AVALIABLE[@]};do
    $(redis-cli -a $MASTERAUTH info replication 2> /dev/null | grep -E 'role|slave') 
    

  echo '{"available": "'"${AVAILABLE[@]}"'", "unavailable":"'"${UNAVAILABLE[@]}"'"}'} | jq
}


main(){
  #parameter setter
  params "$@"

  #bring up a list of servers
  SERVER_LIST=($(cat $FILE_PATH))

  #health check
  if [[ "$HEALTH_CHECK" == "true" ]];then
    PARSED_LIST=$(echo ${SERVER_LIST[@]} | awk '{gsub(":"," ",$0);print $0}')
    echo ${PARSED_LIST[@]}
    health_check ${PARSED_LIST[@]}
  fi

  #perf check
  if [[ "$PERF_CHECK" == "true" ]];then
    perf_check ${SERVER_LIST[@]}
  fi
}

main "$@"