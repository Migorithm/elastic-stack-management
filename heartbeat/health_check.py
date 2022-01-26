import json
from elasticsearch import Elasticsearch
import requests
import json


load_json=json.load(open("./telekey.json"))
key=load_json.get("KEY")
chat_id=load_json.get("CHAT_ID")
telegram_url=f"https://api.telegram.org/bot{key}/sendMessage?parse-mod=html&chat_id={chat_id}"


index_name="heartbeat-*"
body={
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

def connector():
    es= Elasticsearch(["IP1","IP2"],sniff_on_connection_fail=True,sniffer_timeout=30,http_auth=("<id>","<password>"))
    return es

def parser(connector):
    #list_of_services
    service_list=connector.search(index=index_name,body=body,size=0)["aggregations"]["service"]["buckets"]
    for service in service_list:
        service_dict={"service":"","hosts":[]}
        service_name = service["key"]
        service_dict["service"]= service_name
        for ip in service["ip"]["buckets"]:
            ip_address = ip["key"]
            for stat in ip["status"]["buckets"]:
                status = stat["key"]
                service_dict["hosts"].append({"ip":ip_address,"status":status})
        yield service_dict
        #list_of_services.append(service_dict)
    #return list_of_services
        #it should be in a form of, for example {"service":"elasticsearch","hosts":[{"ip":"IP1","status":"up"}]}

def alarm():
    message={"text":""}
    for service in parser(connector()):
        for host in service["hosts"]:
            if host["status"] != "up" :
                message["text"]=f"[ERROR] {service['service']} instance {host['ip']} down!"
                requests.post(telegram_url,message)

if __name__ == "__main__":
    alarm()
    