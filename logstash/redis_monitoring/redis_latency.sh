#!/bin/bash


############################################################################################################
# This script is to sequentially issue query against redis servers and check the following: 
# 1. Latency
# 2. Frequency
# Main idea is with this script, we'll be able to extract data in JSON format and send this to Logstash 
# Prerequisite: jq, redis-cli
# 
#
#
############################################################################################################


help(){
  echo -e "  redismon.sh [OPTIONS] [arg]
    -f, --file [path] Path to the file that lists servers.  (Required)
    -a, --auth        Take masterauth to get access to cluster. (Required)
    -c, --command     Take type of command to be analyzed. (Required)
  "
}

params(){
  
  if [[ "$#" -eq 0 ]];then
    help
    exit 1
  elif [[ -z $(echo "$@" | grep "\-a\|\-\-auth") ]];then
  echo -e "
  [ERROR] Masterauth must be given."
          help
          exit 1
  elif [[ -z $(echo "$@" | grep "\-f\|\-\-file") ]];then
  echo -e "
  [ERROR] File path must be given."
          help
          exit 1
  elif [[ -z $(echo "$@" | grep "\-c\|\-\-command") ]];then
  echo -e "
  [ERROR] Type of command must be given."
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
      elif [[ "${1,,}" == "-a" ]] || [[ "${1,,}" == "--auth" ]]; then
        shift
        MASTERAUTH=$1
        if [[ $MASTERAUTH =~ ^[-] ]]; then
          echo -e "[ERROR] Invalid auth."
          help
          exit 1
        elif [[ -z $MASTERAUTH ]]; then 
        echo -e "
  [ERROR] Masterauth must be given."
          help
          exit 1
        fi
        shift  
      elif [[ "${1,,}" == "-c" ]] || [[ "${1,,}" == "--command" ]]; then
        shift
        COMMAND=$1
        if [[ $COMMAND =~ ^[-] ]]; then
          echo -e "[ERROR] Invalid COMMAND."
          help
          exit 1
        elif [[ -z $COMMAND ]]; then 
        echo -e "
  [ERROR] COMMAND must be given."
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

latency_check(){
  CLUSTER='{"message": []}'
  while [[ $# -gt 0 ]];do
    INSTANCE=$1
    #DATETIME=$(date -d @${2})  if you want this to represent localtime in human readable form
    DATETIME=$2
    MAX_LATENCY_FOR_COMMAND=$4
    FREQUENCY=$(echo $(($(redis-cli -h $(echo $INSTANCE | cut -d ":" -f 1) -p $(echo $INSTANCE | cut -d ":" -f 2) -a $MASTERAUTH latency history $COMMAND 2> /dev/null |wc -l ) /2)) )
    CLUSTER=$(echo $CLUSTER | jq '.message += [{ip:"'"$INSTANCE"'",datetime:"'"$DATETIME"'", latency: "'"$MAX_LATENCY_FOR_COMMAND"'", frequency: "'"$FREQUENCY"'"}]')
    shift 4
  done
  echo $CLUSTER | jq 

#Lastly, we need to flush them out
}


get_available_node(){
  AVAILABLE_NODE=""
  while [[ $# -gt 0 ]]; do
    PING=$(redis-cli -h $1 -p $2 -a $MASTERAUTH ping 2> /dev/null)
    if [[ -z $PING ]]; then
      shift 2

    else
      AVAILABLE_NODE="${1}:${2}"
      break
    fi
  done
  if [[ -z $AVAILABLE_NODE ]];then
    echo -e "
  [ERROR] Available node not found."
  else
    LATENCY_LATEST=$(redis-cli --cluster call $AVAILABLE_NODE latency latest -a $MASTERAUTH 2> /dev/null | grep -v "latency latest")
    COMMAND_LATENCY=($(echo $LATENCY_LATEST | grep -Po "\d+.\d+.\d+.\d+:\d+: $COMMAND \d+ \d+ \d+" | awk '{gsub(": '$COMMAND'","",$0);print $0}'))
    latency_check ${COMMAND_LATENCY[@]}
    fi
}


main(){
  #parameter setter
  params "$@"

  #bring up a list of servers
  SERVER_LIST=($(cat $FILE_PATH))

  PARSED_LIST=$(echo ${SERVER_LIST[@]} | awk '{gsub(":"," ",$0);print $0}')
  get_available_node ${PARSED_LIST[@]}
}
main "$@"