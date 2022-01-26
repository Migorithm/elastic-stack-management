#Create a new index with replication factor
curl -XPUT localhost:9200/new_index -H "Content-Type: application/json" -d '
{ 
	"settings":{ 
		"number_of_shards": 10,
		"number_of_replicas": 1,
	}
}'

#Alias rotation
curl -XPUT localhost:9200/new_index -H "Content-Type: application/json" -d '
{ 
    "actions":[
        { "add" : {"alias":"index_current":"index": "patten_2022_01"}}
        { "remove" : {"alias":"index_current":"index": "patten_2021_12"}}
        { "add" : {"alias":"index_last_three_months":"index": "patten_2022_01"}}
        { "remove" : {"alias":"index_last_three_months":"index": "patten_2021_10"}}   
    ]
}'


#Index Life-Cycle Management
#- Making policy
curl -XPUT localhost:9200/_ilm/policy/policy_name -H "Content-Type: application/json" -d '
{
	"policy" :{
		"phases" :{
			"hot":{
				"actions": {
					"rollover":{
						"max_size":"50GB" ,
						"max_age": "30d"
					}
				}
			},
			"delete" :{ 
				"min_age": "90d",
				"actions":{
					"delete": {}
				}
			}
		}
	}
}'

#- Applying the policy defined above to template
curl -XPUT localhost:9200/_template/template_name -H "Content-Type: application/json" -d '
{ 
	"index_patterns": ["some_patten-*"],
	"settings":{
		"number_of_shards":1,
		"number_of_replicas":1,
		"index.lifecycle.name": "policy_name"
	}
}'


#another example
curl -XPUT localhost:9200/_ilm/policy/policy_name -H "Content-Type: application/json" -d '
{
  "policy":{
    "phases":{
// Even if you don not wanna use hot node setting, configuring hot node is requisite. In that case, you do the following setting. 
      "hot":{
        "min_age":"0m",
        "actions":{
          "set_priority": {
            "priority": null
          } 
        }
      },
      "delete":{
        "min_age":"{how long this index will exist -- 90d, 1h...}",
        "actions":{
          "delete":{}
        }
      }
    }
  }
}
'

curl -XPUT localhost:9200/_template/template_name -H "Content-Type: application/json" -d '
{ 
	"index_pattens" : ["some pattern-*","some other patten-*"],
	"settings": {
		"index.lifecycle.name" :"ILM_policy_name defined above"
	}
}'