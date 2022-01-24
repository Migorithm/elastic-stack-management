########################################################################################################
#
# This script is to let off memory that's being held up on a machine potentially due to memory leak.
# If such a problem is not handled properly, that will lead to OOM and other stuff. So, it's important
# to release the memory every once in a while. 
#
# The issue is the process takes too long time, one instnace for about 15minutes or even more. 
# So, here comes the script. 
#
########################################################################################################


#The following command will prevent replica allocation which will reduce unnecessary I/O
PUT _cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.enable": "primaries"
  }
}

#or

PUT _cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.enable": "none"
  }
}

#To shorten the time it takes to initiate the allocation. 
curl -H "Content-Type: application/json" -XPUT "localhost:9200/_all/_settings" -d '{
    "settings": {
        "index.unassigned.node_left.delayed_timeout":"0"
    }
}'


#Gotta find a way to manipulate host machine individually.
NODE_NAMES=$(curl -XGET "localhost:9200/_cat/nodes?h=node.role,name" |awk '{if(match($1,"d")) print $2}' | sort)
for NODE in $NODE_NAMES; do
    while [[ $(curl --silent -XGET localhost:9200/_cluster/health?pretty| grep status\ 
    | awk '{gsub("\"","",$0);gsub(",","",$0); print $3}') != "green" ]]; do 
        sleep 10 
    done 
    sudo service elasticsearch restart
done



curl -H "Content-Type: application/json" -XPUT "localhost:9200/_all/_settings" -d '{
    "settings": {
        "index.unassigned.node_left.delayed_timeout":"1m"
    }
}'


#Re-enable allocation by setting it to default
PUT _cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.enable": "all"
  }
}