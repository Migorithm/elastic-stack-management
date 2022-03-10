#From 30s ago through current time
curl --user user:password -g --silent IP:9200/heartbeat*/_search?q=@timestamp:["now-30s"+TO+"now"] \
| jq -c '.hits.hits[]._source | [.monitor.name, .monitor.ip, .monitor.status]'


#To see log
sudo journalctl -u heartbeat-elastic.service



mappings_for_heart_beat = {
"mappings": {
	"properties":{
		"monitor.ip":{"type":"keyword"},
		"monitor.name":{"type":"keyword"},
		"monitor.status":{"type":"keyword"}
		}
	}
}

PUT _template/heartbeat-template #6.8version
{ 
  "index_patterns":["heartbeat-*"],
  "settings":{
    "index.lifecycle.name":"liveprobe"
  },
  "mappings":{
    "_doc":{
    "properties":{
      "monitor.ip":{"type":"keyword"},
      "monitor.name":{"type":"keyword"},
      "monitor.status":{"type":"keyword"}
      }
    }
  }
}

query_for_heart_beat={
	"aggs":{
		"service":{
			"terms":{
				"field":"monitor.name"
				},
			"aggs":{
				"ip":{
					"terms":{
						"field":"monitor.ip",
						"size":1000
					},
					"aggs":{
						"status":{
							"terms":{
								"field":"monitor.status"
							}
						}
					}
				}
			}
		}
	},
	"query": {
    "bool": {
      "must": [
        {
          "range": {
            "@timestamp": {
              "gte": "now-30s",
              "lt": "now"
            }
          }
        }
	  ]
	}
  }
}


#Service check
GET heartbeat-{version}-{date}/_search?size=10
{	
  "query": {
    "bool": {
      "must": [
        {
          "range": {
            "@timestamp": {
              "gte": "now-30s",
              "lt": "now"
            }
          }
        },
        {
			"match":{
          "monitor.name":"{service_name}"
        	}
		}
	  ]
	}
}, 
	"_source": ["monitor.status","monitor.ip","monitor.name"]
}