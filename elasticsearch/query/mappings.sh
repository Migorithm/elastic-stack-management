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

