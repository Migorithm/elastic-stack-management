#######################################################################################################################
#
# This program is to check on the current status of services that are subject to monitoring listed in "monitor.d"
# To do that, this program extracts data from Elasticsearch, and if any of the node shows abscence (or down), it alarms
# to Telegram endpoint. And log the information. 
# 
# 
#######################################################################################################################

import json
from elasticsearch import Elasticsearch
import requests
import json
from pathos.multiprocessing import ProcessingPool as Pool
import os
import time
from LogForHealthCheck import logger


load_json=json.load(open("./telekey.json"))
key=load_json.get("KEY")
chat_id=load_json.get("CHAT_ID")
telegram_url=f"https://api.telegram.org/bot{key}/sendMessage?parse-mod=html&chat_id={chat_id}"

#Get available CPU by referring to number of services against available CPUs to this system. Only available on Unix.
NCORE= len(os.sched_getaffinity(0))

index_name="heartbeat-*"
body={	
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
          "monitor.status":"down"
        }
        }
	  ]
	}
}
, "_source": ["monitor.status","monitor.ip","monitor.name"]
,
"aggs":{
  "service":{
    "terms": {
      "field": "monitor.name",
      "size": 50
    },
    "aggs":{
      "ip":{
        "terms": {
          "field": "monitor.ip",
          "size": 50
        }
      }
    }
  }
}
}

#For Dot notation
class Dot(object):
    def __init__(self, data):
        for name, value in data.items():
            setattr(self, name, self._wrap(value))
    def _wrap(self, value):
        if isinstance(value, (tuple, list, set, frozenset)): 
            return type(value)([self._wrap(v) for v in value])
        else:
            return Dot(value) if isinstance(value, dict) else value
    def __repr__(self):
        return str(self.__dict__)

def connector():
    es= Elasticsearch(["IP1:PORT","IP2:PORT"],sniff_on_connection_fail=True,sniffer_timeout=30,http_auth=("<id>","<password>"))
    return es

def parser(connector):
    #list_of_services 
    service_list=Dot(connector.search(index=index_name,body=body,size=0)).aggregations.service.buckets
    for service in service_list:
        service_dict={"service":service["key"],"hosts":[]}
        for ip in service.ip.buckets:
            service_dict["hosts"].append({"ip":ip.key})
        yield service_dict

def alarm(service):
    message={"text":""}
    for host in service["hosts"]:
        message["text"]=f"[ERROR] {service['service']} -- instance {host['ip']} down!"
        requests.post(telegram_url,message)
        #Logging locally.
        logger().warning(f"[HealthCheck] [{host['ip']}] from -- {service['service']} -- DOWN.")

if __name__ == "__main__":
    while True :
        con = connector()
        if con:
            with Pool(NCORE) as executor:
                executor.map(alarm,parser(con))
            time.sleep(60)
        else:
            #In case ES server storing heartbeat data doesn't work
            message = {"text":f"[ERROR] Connection to Monitoring Server Failed"}
            requests.post(telegram_url,message)