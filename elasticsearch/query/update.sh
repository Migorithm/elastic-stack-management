#Update API

# Suppose you have a documment, '{"counter":1, "tags":["red"]}' with id 2
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
	"script" : {
		"source" :"ctx._source.counter += params.count",
		"lang":"painless",
		"params":{
			"count": 4
		}
	}
}' #-> This will result in '{"counter":5, "tags":["red"]}'



#Similarly, if you want to add a new tag to a list of tags,
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
	"script":{
		"source" : "ctx._source.tags.add(params.tag)" 
		"lang":"painless"
		"params":{
			"tag":"blue
		}
	} 
}' #-> This will result in '{"counter":5, "tags":["red","blue"]}'



#To remove 'blue' from the list,
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
	"script":{
		"source": "if (ctx._source.tags.contains(params.tag)){ctx._source.tags.indexOf(params.tag))}",
	"lang" :"painless",
	"params":{
		"tag":"blue"
		}
	}
}' # IF statement was used to avoid possible runtime error. Note that if the list contains duplicates of the tag, this will remove one occurrence.



#Add new field into a source.
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
    "script" :{
        "source" : "ctx._source.new_field = '"'value of new field'"'"
    }
}'

#Remove the field 
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
    "script" :{
        "source" : "ctx._source.remove('"'new_field'"')"
    }
}'

#remove "subfield" from the 'my-object' field.
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
    "script":{
        "source":"ctx._source['"'my-object'"'].remove('"'my-subfield'"')"
        }
}'


#change operation (for example, updating to deleting depending on condition)
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
    "script":{
        "source":"if (ctx._source.contain(params.tag)){ctx.op='"'delete'"'} else {ctx.op='"'none'"'}",
        "lang":"painless",
        "params":{
            "tag":"green"
    }
}'



#Upsert  - if the document doesn't already exists, the contents of the upsert element are inserted as a new document. 
#        - if exists, the script is executed
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/3 -d '
{ 
    "script":{
        "source": "ctx._source.counter += params.count",
        "lang":"painless",
        "params":{
            "count":4
        }
    },
    "upsert":{
        "counter":1
    }
}'

#scripted upsert    - run the script whether or not document exists. Set `script_upsert` to true
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_update/2 -d '
{
    "script_upsert":true,
    "script": {
        "source": """
        if (ctx.op == '"'create'"') {
            ctx._source.counter = params.count
        } else {
            ctx._source.counter += params.count
        }
        """,
        "params":{ 
            "count":4
        }
    },
    "upsert":{}
}'



#Update by Query API

#Syntax
curl -H "Content-Type: application/json" -XPOST localhost:9200/index_name/_update_by_query?conflicts=proceed -d '
{
  "query":{
      "match":{
        "title":"blahblah"
        }
    },
  "script":{
      "source": "ctx.source.count++",
      "lang": "painless"
    }
}'  #If conflict=proceed is not specified, a version conflict should halt the process so you can handle the failure.


#Also possible to do issue a query on multiple indexes and multiple types at once, just like the search API:
curl -H "Content-Type: application/json" -XPOST localhost:9200/indexA,indexB/_update_by_query?conflicts=proceed  -d '
{
    "query":{
        "term":{
            "year":1991
        }
    },
    "script":{
        "source":"ctx.source.tag" = '"'when I was born'"',
        "lang":"painless"
    }

}'



curl -H "Content-Type: application/json" -XPOST localhost:9200/index_name/_update_by_query?conflicts=proceed  -d '
{
    "query":{
    "term":{
    "searchRequirement.masking": "n"
}
},
    "script":{
    "source":"ctx._source.searchRequirement.masking" = '"'false'"',
    "lang":"painless"
    }
}'

