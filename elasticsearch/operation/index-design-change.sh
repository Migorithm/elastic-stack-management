#Index setting
# -- dynamic setting
curl -X PUT "localhost:9200/my-index/_settings?pretty" -H 'Content-Type: application/json' -d'
{
  "index" : {
    "number_of_replicas" : 2  
    "refresh_interval": "1s"        -- If you are planning to index a lot of docs and do not need the new information to be available immediately increase this value.
  }
}'
# -- static setting
curl -X PUT "localhost:9200/my-index/_settings?pretty" -H 'Content-Type: application/json' -d'
{
  "index" : {
    "number_of_shards" : 2  
  }
}'


#Sharding
# -- split 
curl -X PUT "localhost:9200/my-index/_split/my-index-split" -H 'Content-Type: application/json' -d'
{
	"settings":{
		"index.number_of_shards":4      -- This must be muplication factor of the original number of shards.
	}
}'

# -- shrink
curl -X PUT "localhost:9200/my-index/_shrink/my-index-split" -H 'Content-Type: application/json' -d'
{
	"settings":{ 
		"index.number_of_replicas":0,   -- This will make it easier to allocate shards
		"index.number_of_shards":1,     -- This must be dividend of the original number of shards.
		"index.blocks.write": true
    }
}