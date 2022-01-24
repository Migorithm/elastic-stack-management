#Single document DELETE API
curl -H "Content-Type: application/json" -XDELETE localhost:9200/indexname/_doc/<id>

#Multi document Delete by query API
#1
curl -H "Content-Type: application/json" -XDELETE localhost:9200/indexname/_delete_by_query -d '
{
    "query":{
        "match":{
            "fieldname":"value"
        }
    }
}'


#2
curl -H "Content-Type: application/json" -XDELETE localhost:9200/indexname/_delete_by_query -d '
{
    "query":{
        "range":{
            "age":{
                "gte":10
            }
        }
    }
}
'