#/bin/bash


##################################################
# USAGE : remove_red_shard.sh -url ip:9200
#
##################################################
GREEN="\033[0;32m"
RED="\033[0;31m"
ORANGE="\033[0;33m"
PURPLE="\033[0;35m"
NC="\033[0m"
ES_SERVER=""

while [ $# -gt 0 ]
do
	case "$1" in
		-url) ES_SERVER="$2" ;  shift ;;
		--) shift; break ;;
		*) break ;;
	esac
	shift
done

red_shards(){
    #Shard health check
    RED_SHARDS=($(curl --silent -XGET "$ES_SERVER/_cat/shards?h=index,shard,prirep,state,nodSS4e" -H "Content-Type:application/json" | awk '{if ($3=="p" && $4=="UNASSIGNED") print $1}'))
}

# Validating the URL and DB names inputs
if [ -z "$ES_SERVER" ]
then
  echo -e "$RED Elasticsearch URL should be passed like:  -url http://localhost:9200 $NC"
  exit 1
fi



main(){
    expire=$(date +%Y%m%d -d "11 days ago")
    red_shards
    to_be_deleted=()
    for index in ${RED_SHARDS[@]}; do
        get_date=$(echo $index | grep -Po '[0-9]{8}|[0-9]{4}.[0-9]{2}.[0-9]{2}' |tr -dc '0-9')
        if [[] $expire -ge $get_date ]];then
            to_be_deleted+=$index
            echo -e "$ORANGE INDEX: '$index' is about to be deleted... $NC"
        fi
    done  
    if [[ ${#to_be_deleted} -gt 0 ]];then
        echo -e "$GREEN Want to continue? [Y/n] $NC"
        read -n1 answer
        echo ""
        if [[ ${answer,,} == "y" ]]; then
            for notice in ${to_be_deleted[@]};do
                #curl --slient -XDELETE "$ES_SERVER/$notice"
                echo -e "$PURPLE Index: '$index' DELETED"
            done
        else 
            echo -e "$RED Deleting process CANCELED $NC"
        fi
    fi    
}
while true; do
    main
    sleep 60
done