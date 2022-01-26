# Field type mapping
curl -H "Content-Type: application/json" -XPUT 127.0.0.1:9200/movies -d '
{ "mappings" : {
		"properties" : {
			"year" : {"type":"date"}
		}
	}
}'

# Field index -- Whether or not you want the field to be indexed for full-text search
curl -H "Content-Type: application/json" -XPUT 127.0.0.1:9200/movies -d '
{ "mappings" : {
		"properties" : {
			"year" : {
                "type":"date",
                "index":"not_analyzed"
            }
		}
	}
}'


curl -H "Content-Type: application/json" -XPUT 127.0.0.1:9200/movies -d '
{ "mappings" : 
	"properties":{
		"monitor.ip" :{
			"type":"keyword",
			"index":"not_analyzed"
		},
		"monitor.status":{
			"type":"keyword",
			"index":"not_analyzed"
		},
		"monitor.name":{
			"type":"keyword",
			"index":"not_analyzed"
		}

	}
}'

body = {
	"query":{
		"nested":{
			"path":"monitor",
			"query":{
				"match":{
					"monitor.status":"up"
				}
			}
		}
	}
}

body = {
	"mappings":{
		"properties":{
			"monitor":{
				"type":"nested",
				"properties":{
					"ip":{
						"type":"keyword"
					},
					"name":{
						"type":"keyword"
					},
					"status":{
						"type":"keyword"
					}
				}
			}
		}
	}
}

body ={
	"mappings":{
		"properties":{
			"monitor":{
				"type":"object",
				"fields":{
					"ip" :{"type":"keyword"},
					"name":{"type":"keyword"},
					"status":{"type":"keyword"}
				}
			}
		}
	}
}

{
  "aggs": {
    "service": {
      "terms": {
        "field": "monitor.name",
        "size": 20,
        "order": {
          "ip": "desc"
        }
      },
      "aggs": {
        "ip": {
          "cardinality": {
            "field": "monitor.ip"
          }
        },
        "status": {
          "terms": {
            "field": "monitor.status",
            "size": 2,
            "order": {
              "ip": "desc"
            }
          },
          "aggs": {
            "ip": {
              "cardinality": {
                "field": "monitor.ip"
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



body= {
"mappings": {
	"properties":{
		"monitor.ip":{"type":"keyword"},
		"monitor.name":{"type":"keyword"},
		"monitor.status":{"type":"keyword"}
		}
	}
}

query={
	"aggs":{
		"service":{
			"terms":{
				"field":"monitor.name"
				},
			"aggs":{
				"ip":{
					"terms":{
						"field":"monitor.ip"
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
	}
}

ecurl -XGET "10.107.11.59:9200/heartbeat-7.16.3/_search?size=0&pretty" -d '{
"aggs":{"service":{"terms":{"field":"monitor.name"},
"aggs":{"ip":{"terms":{"field":"monitor.ip"},"aggs":{"status":{"terms":{"field":"monitor.status"}}}}}}}}'