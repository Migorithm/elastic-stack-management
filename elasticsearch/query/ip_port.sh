curl -XGET -u 'id:password' "http://{IP}:{PORT}/_cat/nodes?h=i,port" | awk '{print $1, (($2-100))}' | sed 's/ /:/' | sort
