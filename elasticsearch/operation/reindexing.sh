#!/bin/bash

############################################################################################################
# This script is to reindex in the event of cluster red state. 
# The list of indices can be viewed at the endpoint https://<es-cluster-url>:9200/_cat/indices?v 
# And the health of the cluster can be seen at endpoint https://<es-cluster-url>:9200/_cat/health?v.
# 
# The easy way to recover cluster status of which is RED to GREEN is to re-index those RED state indices. 
# The following listing is the steps this script will go through
#
# Step1 : Get all the indices from the ES cluster via https://<es-url>:9200/_cat/indices
# Step2 : Get the RED state indices
# Step3 : Initialize the re-indexing of those red state indices one by one into new indices.
# Step4 : Wait for all the documents underneath to get re-indexed into new index.
# Step5 : Delete the original index that’s in RED state.
# Step6 : From this step the following is optional. If you want to get the old index back, start re-index again from new index to old, already deleted index
# Step7 : Wait for all the documents underneath to get re-indexed into old index again.
# Step8 : Step 8: Now delete the new indices.
#
# For the cooling time it may vary depending on total number of documents in the index. 
# To allow for that variability, you can use proportional values like: "cool $(echo $ind | awk ‘{print $7/10}’)" 
#
# Reindexing job is I/O bound work -- you have to be aware of I/O throughput of your hardware and network bandwidth too. 
############################################################################################################


GREEN="\033[0;32m"
RED="\033[0;31m"
ORANGE="\033[0;33m"
PURPLE="\033[0;35m"
NC="\033[0m"
ES_SERVER=""

reindex() {
	echo -e "$GREEN Reindexing from $1 to $2 $NC"
	curl -X POST "$ES_SERVER/_reindex?requests_per_second=10000" \
	-H "Content-Type:application/json" \
	-d '{
		  "source": {
		    "index": "'$1'"
            "size": 10000
		  },
		  "dest": {
		    "index": "'$2'"
		  }
		}'
}

delete_index() {
	echo -e "$RED Deleting the $1 index $2$NC"
	curl -X DELETE $ES_SERVER/$2
}
cool() {
	echo -e "\n$PURPLE Giving cooling time to ES Server for $1 seconds $NC"
	sleep $1s;
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
read -p "$(echo -e $PURPLE Using $ES_SERVER URL for re-indexing operation, Are you sure to proceed? $NC)" $REPLY
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
	set -e
	# Collecting all the indicies
	echo -e "$GREEN Using $ES_SERVER as endpoint url and storing the index to ./index.yaml$NC"
	echo -e "$RED"
	curl --silent $ES_SERVER/_cat/indices > ./index.yaml
	echo -e "$NC"
	# Segregating red indicies
	echo -e "$GREEN Segregating the red indices from overall index list and storing to ./red-index.yaml$NC"
	cat ./index.yaml | awk '{if ( $1 =="red") print $0;}' > ./red-index.yaml
	# reading and iterating over the red indicies
	while read ind; do
		index=$(echo $ind | awk '{print $3}')
		newIndex="${index}_new"
		echo -e "$ORANGE Working on the index: $index$NC"
		echo -e "$ORANGE New Index will be $newIndex$NC"
		
		reindex $index $newIndex
		cool $(echo $ind | awk '{print $7/10}')
		delete_index "original" $index
		cool $(echo $ind | awk '{print $7/10}')
		reindex $newIndex $index
		cool $(echo $ind | awk '{print $7/10}')
		delete_index "duplicated" $newIndex
		cool $(echo $ind | awk '{print $7/10}')
		echo -e "$GREEN Done with the index $index $NC"
		echo ""
		echo ""
	done <./red-index.yaml
else
	echo -e "$ORANGE Aborting operation$NC"
fi

#To clean up temporary files which contains index info
echo "Cleaning up the local files...."
rm ./index.yaml
rm ./red-index.yaml
