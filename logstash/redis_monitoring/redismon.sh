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
    -c, --cluster     Check available/unavailable node in a cluster and its topology.
    -a, --auth        Take masterauth to get access to cluster. (Required)
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



health_check(){

  AVAILABILITY='{"availability":{"available": [] , "unavailable":[]}}'
  while [[ $# -gt 0 ]]; do
    PING=$(redis-cli -h $1 -p $2 -a $MASTERAUTH ping 2> /dev/null)
    if [[ -z $PING ]]; then
      echo -e "  [FAIL] Connection refused : $1:$2"
      IP_PORT="${1}:${2}"
      AVAILABILITY=$(echo "$AVAILABILITY" | jq '.availability.unavailable += ["'"$IP_PORT"'"]')
      shift
      shift
    else
      IP_PORT="${1}:${2}"
      echo -e "  [SUCCESS] Connected : $1:$2"
      AVAILABILITY=$(echo "$AVAILABILITY" | jq '.availability.available += ["'"$IP_PORT"'"]')
      shift
      shift
    fi
  done



  
  AVAILABLE_INSTANCE=$(echo $AVAILABILITY | jq -r .availability.available[0])
  #To remove double quotes, it's necessary to put "-r" flag

  #To prevent IO bottleneck
  INFO=$(redis-cli --cluster call ${AVAILABLE_INSTANCE} info -a $MASTERAUTH 2> /dev/null | tr -d '\r')

  #to show current topology 
  master_num=1
  slave_num=1
  TOPOLOGY=($(redis-cli --cluster call ${AVAILABLE_INSTANCE} info replication -a $MASTERAUTH 2> /dev/null |  tr -d '\r' |  tr "\n" " "   |  grep -Po '[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}.[0-9]{4,5}: # Replication role:master|slave[0-9]:ip=[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3}.[0-9]{2,3},port=[0-9]{4,5},state=(online|offline)' |  awk '{gsub(": # Replication ", " ",$0);gsub(",port=",":",$0);print $0}' |  sed 's/role:master//'))
  # ** tr -d '\r' ** is required to replace ^M that comes from window/dos

  SHARDS='{"topology":{}}'
  for node in ${TOPOLOGY[@]};do
    if [[ $node =~ ^[0-9] ]];then
      if [[ -n $shard ]]; then
        shard=$(echo $shard |jq -r)
        SHARDS=$(echo $SHARDS | jq '.topology += '"$shard"'')
      fi
      slave_num=1
      shard=$(echo '{"'shard_${master_num}'":{"master":"'$node'" }}')
      shard_num=$master_num
      ((master_num ++))
    elif [[ $node =~ ^slave ]]; then

      slave_ip=$(echo $node | grep -Po '\d+.\d+.\d+.\d+:\d+')
      slave_status=$(echo $node |grep -Po '(online|offline)')
      shard=$(echo $shard | jq '."'shard_${shard_num}'" += {"'slave_$slave_num'": {ip:"'$slave_ip'", status:"'$slave_status'"}}')
      (( slave_num++ ))

    fi

  done
  SHARDS+=($shard)
  }

shard=$(echo '{"'shard_${master_num}'":{"master":"'$node'" }')
shard=$(echo $shard | jq '."'shard_${master_num}'" += {"'slave_$slave_num'": "'$slave_ip'", "status":"'$slave_status'"}')


perf_check(){
  while [[ $# -gt 0 ]];do
    INSTANCE=$1
    COMMAND_PROCESSED_PER_SEC=$2
    HIT_RATE=$(bc -l <<< $3/$4)

  done

}
  

main(){
  #parameter setter
  params "$@"

  #bring up a list of servers
  SERVER_LIST=($(cat $FILE_PATH))

  PARSED_LIST=$(echo ${SERVER_LIST[@]} | awk '{gsub(":"," ",$0);print $0}')
  health_check ${PARSED_LIST[@]}

  #health check based on slot assigned and available nodes
  if [[ "$HEALTH_CHECK" == "true" ]];then
    if [[ ${#SERVER_LIST[@]} == $(echo $AVAILABILITY | jq -r '.availability.available | length') ]] && [[ $(echo ${CLUSTER_INFO[@]} | grep -P "cluster_slots_assigned:\d+" -o | grep -Po "\d+") == "16384" ]];then
      HEALTH=$(echo '{"Cluster health" : "green"}' | jq -r)

    elif [[ ${#SERVER_LIST[@]} != $(echo $AVAILABILITY | jq -r '.availability.available | length') ]] && [[ $(echo ${CLUSTER_INFO[@]} | grep -P "cluster_slots_assigned:\d+" -o | grep -Po "\d+") == "16384" ]];then
      HEALTH=$(echo '{"Cluster health" : "yellow"}' | jq -r)
    else
      HEALTH=$(echo '{"Cluster health" : "red"}' | jq -r)

    fi
    FARM='{"Farmname":"Redis_FarmA"}'
    AVAILABILITY=$(echo $AVAILABILITY |jq -r)
    TOPOLOGY_FIN=$(echo ${SHARDS[@]} |jq -r)
    echo $FARM $combined $AVAILABILITY $TOPOLOGY_FIN $HEALTH | jq -r -s add
  fi




  #perf check
  if [[ "$PERF_CHECK" == "true" ]];then
    PERF=$(echo $INFO | grep -P "\d+.\d+.\d+.\d+:\d+|instantaneous_ops_per_sec:\d+|keyspace_\w+:\d+" -o)
    perf_check ${PERF[@]}

  fi
}

main "$@"