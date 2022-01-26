#From 30s ago through current time
curl --user user:password -g --silent IP:9200/heartbeat*/_search?q=@timestamp:["now-30s"+TO+"now"] \
| jq -c '.hits.hits[]._source | [.monitor.name, .monitor.ip, .monitor.status]'

