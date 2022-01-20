#!/bin/bash

############################################################################################################
# This script is to allocate empty primary shard in the event of cluster red state. 
# The list of indices can be viewed at the endpoint https://<es-cluster-url>:9200/_cat/indices?v 
# And the health of the cluster can be seen at endpoint https://<es-cluster-url>:9200/_cat/health?v.
# 
# The easy way to recover cluster status of which is RED to GREEN is to re-index those RED state indices. 
# The following listing is the steps this script will go through
#
# To run this script, you just need to pass in Elasticsearch cluster endpoint preceded by -url 
# For example - allocation_primary.sh -url localhost:9200
############################################################################################################

GREEN="\033[0;32m"
RED="\033[0;31m"
ORANGE="\033[0;33m"
PURPLE="\033[0;35m"
NC="\033[0m"
ES_SERVER=""

red_shards(){
    #Shard health check
    RED_SHARDS=($(curl --silent -XGET "$ES_SERVER/_cat/shards?h=index,shard,prirep,state,node" -H "Content-Type:application/json" | awk '{if ($3=="p" && $4=="UNASSIGNED") print $1,$2}'))
    AVAILABLE_NODES=($(curl --silent -XGET "$ES_SERVER/_cat/allocation?h=node" -H "Content-Type:application/json" | awk '{if ($1 !="UNASSIGNED") print $1}'))
}
allocate() {
    while [[ $# -gt 0 ]];do 
        rand=$[ $RANDOM %${#AVAILABLE_NOEDS[@]} ]
        curl -X POST "$ES_SERVER/_cluster/reroute" \
	    -H "Content-Type:application/json" \
	    -d '{
		  "commands: [
              {"allocate_empty_primary":{ 
                  "index": "'$1'",
                  "shard" : "'$2'",
                  "node": "'${AVAILABLE_NODES[$rand]}'"
                  "accept_data_loss":"true" 
                  }
                }
                    ]
        }'
        shift 2
    done
}

while [ $# -gt 0 ]
do
	case "$1" in
		-url) ES_SERVER="$2" ;  shift ;;
		--) shift; break ;;
		*) break ;;
	esac
	shift
done

# Validating the URL and DB names inputs
if [ -z "$ES_SERVER" ]
then
  echo -e "$RED Elasticsearch URL should be passed like:  -url http://localhost:9200 $NC"
  exit 1
fi

read -p "$(echo -e $PURPLE Using $ES_SERVER URL for allocation operation, Are you sure to proceed? $NC)" $REPLY
echo ""
if [[ $REPLY =~ ^[Yy]$ ]];then
	set -e
    echo -e "$GREEN Shard health check...$NC"
    red_shards
    if [[ ${#RED_SHARD[@]} -gt 0 ]]; then
        echo -e "$RED there are ${#RED_SHARD[@]} shards in red status $NC"
        echo -e "$GREEN empty primary will be allocated...$NC"
        allocate ${RED_SHARD[@]}
    else 
        echo -e "$GREEN No shard in red state is found. $NC"
        exit 0
    fi

else
	echo -e "$ORANGE Aborting operation$NC"
fi


