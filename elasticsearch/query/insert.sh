#Index API


#Simple POST
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_doc/ -d  #without id
'{ "genre" : ["IMAX","Sci-Fi"], 
	"title": "Interstellar",
	"year":2014}'

#Simple PUT
curl -H "Content-Type: application/json" -XPUT localhost:9200/movies/_doc/2 -d  #with ID
'{
"counter":1,
"tags":["red"]
}'

#Bulk import
curl -H "Content-Type: application/json" -XPUT localhost:9200/_bulk -d '
{ "create" : { "_index" : "movies", "_id" : "135569" } }
{ "id": "135569", "title" : "Star Trek Beyond", "year":2016 , "genre":["Action", "Adventure", "Sci-Fi"] }
{ "create" : { "_index" : "movies", "_id" : "122886" } }
{ "id": "122886", "title" : "Star Wars: Episode VII - The Force Awakens", "year":2015 , "genre":["Action", "Adventure", "Fantasy", "Sci-Fi", "IMAX"] }
{ "create" : { "_index" : "movies", "_id" : "109487" } }
{ "id": "109487", "title" : "Interstellar", "year":2014 , "genre":["Sci-Fi", "IMAX"] }
{ "create" : { "_index" : "movies", "_id" : "58559" } }
{ "id": "58559", "title" : "Dark Knight, The", "year":2008 , "genre":["Action", "Crime", "Drama", "IMAX"] }
{ "create" : { "_index" : "movies", "_id" : "1924" } }
{ "id": "1924", "title" : "Plan 9 from Outer Space", "year":1959 , "genre":["Horror", "Sci-Fi"] }
'

#Bulk import file
curl -H "Content-Type: application/json" -XPUT localhost:9200/_bulk --data-binary @file_name
#--data-binary gives you the way of importing data into curl from a file which is different from -d which indicates --date-raw


#Full update request
curl -H "Content-Type: application/json" -XPUT localhost:9200/movies/_doc/109487?pretty -d '
{
"genres" : ["IMAX","Sci-Fi"],
"title" : "Interstellar foo",
"year" :2014
}'

#Partial update
curl -H "Content-Type: application/json" -XPOST localhost:9200/movies/_doc/109487/_update -d '  
{
	"doc" : {
	"title" : "Interstellar"
	}
}'



