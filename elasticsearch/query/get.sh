# Single documet get API
curl -H "Content-Type: application/json" -XGET localhost:9200/indexname/_doc/<id>


#Search API
#1 size
curl -H "Content-Type: application/json" -XGET localhost:9200/indexname/_search -d '{
    "size":1
}'

#2 _source : indicates which source fields are returned
curl -H "Content-Type: application/json" -XGET localhost:9200/indexname/_search -d '{
"_source":["field1","field2"]}'

#3 timeout : specify the period of time to wait for a response from each shard. Defaults to no timeout
curl -H "Content-Type: application/json" -XGET localhost:9200/indexname/_search -d '{
"timeout":"5s"    
}'



################################################################################################


# QUERY : Using query DSL, you can define queries.


################################################################################################
# -- Leaf query clauses : it looks for a particular value in a particular field such as match, term or range. These query can be used by themselves.
# -- Compound query clauses : this wraps other leaf or other compound queries and are used to combine multiple queries, such as bool, dis_max
# -- Expensive query : certain queries are more expensive due to the way they are implemented.
#    -- those are:
#       -- `script` as it requires linear scans to identify matches
#       -- `fuzzy`, `regexp`, `prefix`, `wildcard`, `range`      
#       -- `join`
# -- Query context : How WELL this document match the query clause?
# -- Filter context : is it matched? 
curl -H "Content-Type: application/json" -XGET localhost:9200/indexname/_search -d '{
    "query" : {                                                 -- "query" parameter indicate query context
        "bool":{                                                -- "bool" and two "match" clauses are used in query context, meaning they are used to score relevancy
            "must":[                                            -- "must", "should" have their scores combined so it is in query context while "must_not" and "filter" are in filter context.
                {"match":{"title":"Search"}},
                {"match":{"content":"Elasticsearch}}
            ],
            "filter":[                                          -- "filter" parameter indicates filter context. Its "term" and "range" clauses are used in filter context.
                {"term": {"status":"published"}},                   -- therefore scoring is ignored and clauses are considered for CACHING. 
                {"range":{"publish_date":{"gte":"2021-12-12"}}}
            ]
        }
    }
}'



# Bool -- must, should  VS  must_not, filter
curl -H "Content-Type: application/json" -XGET localhost:9200/indexname/_search -d '{
{
  "query": {
    "bool" : {
      "must" : {
        "term" : { "user.id" : "kimchy" }
      },
      "filter": {
        "term" : { "tags" : "production" }
      },
      "must_not" : {
        "range" : {
          "age" : { "gte" : 10, "lte" : 20 }
        }
      },
      "should" : [
        { "term" : { "tags" : "env1" } },
        { "term" : { "tags" : "deployed" } }
      ],
      "minimum_should_match" : 1,               --  to specify the number of "should" clauses returned documents must match.
      "boost" : 1.0
    }
  }
}'


# Full text queries https://www.elastic.co/guide/en/elasticsearch/reference/current/full-text-queries.html