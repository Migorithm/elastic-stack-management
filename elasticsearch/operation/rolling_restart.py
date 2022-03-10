from elasticsearch import Elasticsearch 
import time 
from itsdangerous import TimedJSONWebSignatureSerializer as Serializer
import os
import requests



def connector() -> Elasticsearch:
    es= Elasticsearch(["https://10.107.11.66:9200","https://10.107.11.59:9200"],
                      sniff_on_node_failure=True,sniff_timeout=30,
                      http_auth=("elastic" , "5ctsG+MNUa*ttbQ4i5*d"),
                      verify_certs=False #Same as "-k"
                      )
    return es

def token_generator() -> str:
    serializer= Serializer("AGENT_KEY",300)
    return serializer.dumps({"confirm":True}).decode("utf-8")
    

es_con = connector()
nodes = ["http://10.107.11.66:5000","http://10.107.11.56:5000","http://10.107.11.59:5000"]

for node in nodes:
    print(node)
    while True : 
        try :
            if es_con.cluster.health()['status'] =="green":
                print("Cluster health green! Continue rolling restart...")
                print("execute 1") #to be replaced with post request
                token = token_generator()
                print(token)
                res=requests.post(node+"/command/restart",json={"token":token})
                if res.status_code == 200:
                    print(f"Agent : {node} executed Restart...")
                    time.sleep(10) 
        except Exception as e:
            print(f"Error occured! {e}")
            print(e.args)
        else:
            cnt=1
            #Proceeding with rolling restart with cluster health being yellow or red is banned. 
            while es_con.cluster.health()['status'] != "green":
                print("Cluster health not green! give it a little sec")
                print(f"Tried {cnt} times...")
                print(f"The most recent execution was on {node}")
                time.sleep(10)
                cnt+=1
                continue
            else:
                break
     
        
