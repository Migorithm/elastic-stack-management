#If ever there is an issue
curl -H "Content-Type: application/json" -XGET localhost:9200/_cluster/allocation/explain?pretty

#Delaying the allocation of unassigned node 
curl -H "Content-Type: application/json" -XPUT localhost:9200/_all/_settings -d '{
  "settings": {
    "index.unassigned.node_left.delayed_timeout": "5m"
  }
}'

#If you want to remove a node permanently right after issue occurs.
curl -H "Content-Type: application/json" -XPUT localhost:9200/_all/_settings -d '{
{
  "settings": {
    "index.unassigned.node_left.delayed_timeout": "0"
  }
}'

#re-enable shard allocation
curl -XPUT "localhost:9200/_cluster/settings?pretty" -H 'Content-Type: application/json' -d'
{
    "transient" : {
        "cluster.routing.allocation.enable" : "all"
    }
}'


#Force allocate empty primary shard
curl -XPOST "localhost:9200/_cluster/reroute?pretty" -H 'Content-Type: application/json' -d'
{
    "commands" : [
        {
          "allocate_empty_primary" : {
                "index" : "constant-updates", 
                "shard" : 0,
                "node" : "<NODE_NAME>", 
                "accept_data_loss" : "true"
          }
        }
    ]
}'

#Watermark change
# - Transiently
curl -XPUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "transient": {
    "cluster.routing.allocation.disk.watermark.low": "90%",
    "cluster.routing.allocation.disk.watermark.high": "95%"
  }
}'

# - Permatently
curl -XPUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "cluster.routing.allocation.disk.watermark.low": "90%",
    "cluster.routing.allocation.disk.watermark.high": "95%"
  }
}'
