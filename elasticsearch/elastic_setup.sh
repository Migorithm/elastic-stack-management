#!/bin/bash

#####################################################################################################################################
#For 7.17 and below
#This script was made for the sake of streamlining the process of Elasticsearch setup. You can  can be run without parameter.
#This script doesn't need any parameter to put, albeit requiring user input to get the followings.
#It should be noted that when square bracket("[]") is prompted, values in the square bracket is default value.

#1 - JDK version that you want to install
#2 - Elasticsearch version
#3 - Is the setup environment Production? or anything else?
#4 - Cluster name
#5 - Node name
#6 - Roles of the node (master,data,ingest)
#7 - IP settgins :: This should be one or more IPs with space-separate values
#8 - DataPATH :: Path to data storage
#8 - JVM Memory -- pending
#####################################################################################################################################



connection_check(){
	arr=("$@")
	RES=0

	#to collect the server to which you failed to get access
	failed_to_connect=()
	seccess_to_connect=()
	for i in "${arr[@]}";
	do
		#Connvetion check
		echo "Conneting to ${i}... "
		ping -W 2 -c 3 $i 2>&1 > /dev/null
		RES=$?
		if [[ $RES -gt 0 ]]; then
			echo "Connection timeout. Check if it is possible to connect to the following IP : '${i}'"
			failed_to_connect+=($i)
		else
			success_to_connect+=($i)
		fi
	done
	return ${#failed_to_connect[@]}
}


#The function below is to get user inputs that dictates versions and configurations to be set
user_input(){

	##JDK
	printf "The following is a list of jdk available for this repository\n"
	apt-cache search openjdk | grep "^openjdk-[0-9]\{1,2\}-jdk" |grep "8\|11"
	read -p "Enter JDK version you want to install [11]: " jdk_version
	jdk_version=${jdk_version:-11}
	while [[ ! "$jdk_version" =~ [0-9][0-9]? ]]; do
		echo -e "There is no such a jdk version.\n"
		read -p "Please enter the right JDK version you want to install [11]: " jdk_version
		jdk_version=${jdk_version:-11}
    done




	##ES
	read -p "Enter Elasticsearch version you want to install [7.17.1]: " es_version
    es_version=${es_version:-"7.17.1"}
	while ! [[ "$es_version" =~ [0-9]\.[0-9]{1,2}\.[0-9]{1,2} ]]; do
        printf "The given Elasticsearch version is malformed. Retry...\n"
        read -p "Enter Elasticsearch version you want to install [7.17.1]: " es_version
        es_version=${es_version:-"7.17.1"}
	done;
    

	#is_prod?
	read -p "Are you on PROD server? [Y/n] > " is_prod
    is_prod=${is_prod::1};is_prod=${is_prod,,}
	while ! [[ ${is_prod,,} == "y" || ${is_prod,,} == "n" ]];do
        printf "\nInvalid input. Please enter the right answer.\n"
        read -p "Are you on PROD server? [Y/n] : " -n1 is_prod
        is_prod=${is_prod::1};is_prod=${is_prod,,}
	done;
	
	

	##role and name
	echo 
	read -ep "Enter the cluster name : " CLUSTER_NAME
    read -ep "Enter the name of the node : " node_name
    read -ep "Would you like this node to be a master node? [Y/n]: " master
    read -ep "Would you like this node to be a data node? [Y/n]: " data
    read -ep "Would you like this node to be a ingest node? [Y/n]: " ingest
    master=${master::1};master=${master,,}
    data=${data::1};data=${data,,}
    ingest=${ingest::1};ingest=${ingest,,}

    while [[ ! (  ${master,,} == "y" ||  ${master,,} == "n" ) || ! (  ${data,,} == "y" || ${data,,} == "n" ) || ! ( ${ingest,,} =~ "y" || ${ingest,,} =~ "n" ) ]]; do
        printf "\nInvalid input. Please choose either true or false.\n"
        read -ep "Would you like this node to be a master node? [Y/n]: " master
    	read -ep "Would you like this node to be a data node? [Y/n]: " data
    	read -ep "Would you like this node to be a ingest node? [Y/n]: " ingest
        master=${master::1};master=${master,,}
        data=${data::1};data=${data,,}
        ingest=${ingest::1};ingest=${ingest,,}
    done


  	##IP setting
  	if [[ -f "/etc/elasticsearch/elasticsearch.yml" ]]; then
  		echo "elasticsearch.yml already exists."
  		EXISTING_IP=$(sudo grep discovery /etc/elasticsearch/elasticsearch.yml | grep "\[" | awk '{gsub("\\[","",$0);gsub("\\]","",$0);gsub("\"","",$0);print $2}' | awk '{gsub(","," ",$0);print$0}' )
    	printf "Masters' IPs are being configured... Enter one or more IPs \nEx) $EXISTING_IP\n: " 
    	read -a IP_LIST
    else 
    	printf "Masters' IPs are being configured... Enter one or more IPs \nEx) 10.107.11.59 10.107.11.56 10.107.11.66\n: " 
    	read -a IP_LIST
    fi
    

    #Duplicate check
    uniq_ip=$(echo ${IP_LIST[@]} | tr ' ' '\n' | uniq | wc -l)
    while  [[ $uniq_ip !=  ${#IP_LIST[@]} ]]; do
    	printf "There is a duplicate IP. Enter the right IPs...\n"
    	printf "Enter one or more IPs \nEx) 10.107.11.59 10.107.11.56 10.107.11.66\n: "  # should add duplicate check
    	read -a IP_LIST
    done

    #Connection check
    connection_check "${IP_LIST[@]}"
    connection_response="$?"

    while  [[ $connection_response -gt 0 ]]; do
    	echo -e "Connection to the following server has succeeded.\n${success_to_connect[@]}\n"
    	echo -e "However, connection to the follwoing server has failed.\n${failed_to_connect[@]}"
    	printf "\nEnter one or more IPs \nEx) 10.107.11.59 10.107.11.56 10.107.11.66\n: "  # should add duplicate check
    	read -a IP_LIST
    	connection_check "${IP_LIST[@]}"
    	connection_response="$?"
    done
    
    #Putting ID into Square bracket so it is matched with required format in elasticsearch.yml
    cnt=0
    IPS=""
	for i in "${IP_LIST[@]}"
	do
    	if [[ -n "$i" && $cnt -eq 0 ]]; then
            if [[ ${#IP_LIST[@]} -eq 1 ]];then
                    IPS+="[\"$i\"]"
            else
                    IPS+="[\"$i\","
                    ((cnt+=1))
            fi

    	elif [[ ${#IP_LIST[@]}-1 -eq $cnt ]]; then
            IPS+="\"$i\"]"
    	else
            ((cnt+=1))
            IPS+="\"$i\","
    	fi
	done

	#Path to directory
	read -p "Path to directory where to store the data [/var/lib/elasticsearch] > " DATA_PATH
	DATA_PATH=${DATA_PATH:-"/var/lib/elasticsearch"}
    


    if sudo test -f /etc/elasticsearch/elasticsearch.dpkg-dist;then
			echo "You chose not to overwrite existing elasticsearch.yml file..."
    fi
    #JVM memory allocation
    echo "The total and available memory is as follows."
    head -3 /proc/meminfo
    #To set half the memory out of total memory, uncomment the following and comment out the one after.
    half_the_memory=$(( $(head -1 /proc/meminfo |awk '{print$2}')/2000000 )) 
    read -ep "Enter the size of JVM jeap memory you want to allocate in Gigabyte. [$half_the_memory]g: " memory
    memory=${memory:-$half_the_memory}

    if [[ $es_version =~ ^7 ]]; then 
        read -p "For Elasticsearch version 7 and above, JVM is automatically allocated. Will you overwrite it? default:n [y/n] " overwrite
        overwrite=${overwrite::1};overwrite=${overwrite,,}
        overwrite=${overwrite:-n}
    else 
        if [[ $jdk_version -gt 10 ]];then
            echo "It is possible to apply G1GC setting for given JDK."
            read -p "Use G1GC [Y/n] :" -n 1 G1GC
            G1GC=${G1GC:-y}
        fi
    fi




    	
    printf "\n\n\n"
    echo "########################################################################"
    printf "\n\n\n"
    echo "The following is configuration for this Elasticsearch node"
    echo "JDK version : $jdk_version"
    echo "Elasticearch version : $es_version"
    echo "Cluster name : $CLUSTER_NAME"
    echo "Node name for this instance : $node_name"
    echo "Master,Data,Ingest : $master,$data,$ingest"
    echo "Running environment - is prod? : $is_prod"
    echo "A list of IPs to discover cluster : $IPS"
    echo "Path to data directory: $DATA_PATH"
    if [[ "$es_version" =~ ^7 ]]; then
        if [[ "${overwrite,,}" == "n" ]]; then
                echo "Allocated JVM Memory : automatic allocation"
        else
                echo "Allocated JVM Memory : $memory"
        fi
    else
        echo "Allocated JVM Memory : $memory"
    fi
    printf "\n\n\n"
    echo "########################################################################"
    printf "\n\n\n"
}




#java check
#java_install(){
#	sudo apt-get update
#    sudo apt-get install openjdk-$jdk_version-jdk
#    sudo java -version        
#}




#version check should be added

#Elasticsearch setup
elastic_setup() {
        while true ; do
            case "$is_prod" in
                "y")
					if [[ $es_version =~ ^[7] ]]; then
                    	check=$(shasum -a 512 -c elasticsearch-${es_version}-amd64.deb.sha512 | grep OK)
                    	if [[ -n $check ]]; then 
							sudo dpkg -i elasticsearch-$es_version-amd64.deb
							break
						else
							echo "Data integrity is not validated. You may want to reinstall the package or archive."
							echo "Program exits..."
							exit 1
						fi
                    elif [[ $es_version =~ ^[6] ]]; then
                    	check=$(shasum -a 512 -c elasticsearch-${es_version}.deb.sha512 | grep OK)
                    	if [[ -n $check ]]; then 
							sudo dpkg -i elasticsearch-$es_version.deb
							break
						else
							echo "Data integrity is not validated. You may want to reinstall the package or archive."
							echo "Program exits..."
							exit 1
						fi
                   
					fi
					;;
                "n")
                    if [[ $es_version =~ ^[7] ]]; then
        	            wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$es_version-amd64.deb
                        wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$es_version-amd64.deb.sha512
						check=$(shasum -a 512 -c elasticsearch-${es_version}-amd64.deb.sha512 | grep OK)
						if [[ -n $check ]]; then 
							sudo dpkg -i elasticsearch-$es_version-amd64.deb
							break
						else
							echo "Data integrity is not validated. You may want to reinstall the package or archive."
							echo "Program exits..."
							exit 1
						fi
                    elif [[ $es_version =~ ^[6] ]]; then
                        wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$es_version.deb
                        wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$es_version.deb.sha512
                        check=$(shasum -a 512 -c elasticsearch-${es_version}.deb.sha512 | grep OK)
						if [[ -n $check ]]; then 
							sudo dpkg -i elasticsearch-$es_version.deb
							break
						else
							echo "Data integrity is not validated. You may want to reinstall the package or archive."
							echo "Program exits..."
							exit 1
						fi
                	fi
                        ;;
            esac
        done
}

#Joiner for array element
join_by (){
	local IFS="$1"; shift; 
	echo "$*"
}

#configuration setting
es_config(){
	# $1 -> Path to original configuration file
	IN=$1
    
	sudo sed -i -f - "$IN" <<-SED_SCRIPT
		s/#network.host:.*/network.host: 0.0.0.0\nhttp.cors.enabled: true\nhttp.cors.allow-origin: '*'\ntransport.port: 9300/
		s/#http.port:.*/http.port: 9200/
		s|.*cluster.name.*|cluster.name: ${CLUSTER_NAME}|
		s|#cluster.name.*|cluster.name: ${CLUSTER_NAME}|
        s|path.data.*|path.data: ${DATA_PATH}|

	SED_SCRIPT

	#turns out, at version 6, there is no default parameter name discovery.seed_hosts and cluster.initial_masater_nodes.. let's branch this out.
	if [[ $es_version =~ ^6 ]]; then
		master_data_ingest=("$master" "$data" "$ingest")
		cnt=0
		for i in ${master_data_ingest[@]}; do
			if [[ "$i" == "y" ]];then
				master_data_ingest[$cnt]="true"
				((cnt++))
			else
				master_data_ingest[$cnt]="false"
				((cnt++))
			fi
		done
		sudo sed -i -f - "$IN" <<-_EOF_
			s|.*discovery.zen.ping.unicast.hosts:.*|discovery.zen.ping.unicast.hosts: ${IPS}|
			s|.*discovery.zen.minimum_master_nodes:.*|discovery.zen.minimum_master_nodes: 1|
			s|#node.name.*|node.name: ${node_name}\nnode.master: ${master_data_ingest[0]}\nnode.data: ${master_data_ingest[1]}\nnode.ingest: ${master_data_ingest[2]}|
		_EOF_
		
	else
		roles=()
		if [[ $master == 'y' ]]; then
			roles+=(master)
		fi
		if [[ $data == 'y' ]]; then
			roles+=(data)
		fi
		if [[ $ingest == 'y' ]]; then
			roles+=(ingest)
		fi
		node_roles="[$(join_by , ${roles[@]})]"  

		sudo sed -i -f - "$IN" <<-_EOF_
			s/#discovery.seed_hosts.*/discovery.seed_hosts: ${IPS}/
			s/#cluster.initial_master_nodes.*/cluster.initial_master_nodes: [\"${IP_LIST[0]}\"]/
			s|#node.name.*|node.name: ${node_name}\nnode.roles: $node_roles|

		_EOF_

	fi 
	sudo bash -c  "sudo echo '
# --------------------------- Security -----------------------------
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12
' >> $IN"
}






jvm_config (){
	#IN - orignal file
	IN=$1
	#OUT - modified version

	#Memory set
	#While at version 7, jvm is automatically configured based on available memory in our system so the option is commented out,
	#that is not the case for version 6, necessitating the need for branching. 
	if [[ -n $memory && $memory =~ [0-9]{1,3} ]]; then
		if [[ $es_version =~ ^6 ]]; then 
			if [[ "${G1GC,,}" == "y" ]]; then
				sudo sed -i -f - "$IN" <<-USE_G1GC
					s|^-Xms.*|-Xms${memory}g|
					s|^-Xmx.*|-Xmx${memory}g|
					s|.*-XX:+UseConcMarkSweepGC|##-XX:+UseConcMarkSweepGC|
					s|.*-XX:CMSInitiatingOccupancyFraction=75|##-XX:CMSInitiatingOccupancyFraction=75|
					s|.*-XX:+UseCMSInitiatingOccupancyOnly|##-XX:+UseCMSInitiatingOccupancyOnly|
					s|.*-XX:-UseConcMarkSweepGC|$jdk_version-:-XX:-UseConcMarkSweepGC|
					s|.*-XX:-UseCMSInitiatingOccupancyOnly|$jdk_version-:-XX:-UseCMSInitiatingOccupancyOnly|
					s|.*-XX:+UseG1GC|$jdk_version-:-XX:+UseG1GC|
					s|.*-XX:InitiatingHeapOccupancyPercent=75|$jdk_version-:-XX:InitiatingHeapOccupancyPercent=75|
				USE_G1GC
				echo "G1GC has been set successfully"
			else
				sudo sed -i -f - "$IN" <<-USE_CMS
				s|^-Xms.*|-Xms${memory}g|
				s|^-Xmx.*|-Xmx${memory}g|
				USE_CMS
			fi

		else 
			if [[ ${overwrite,,} == "y" ]]; then
				sudo sed -i -f - "$IN" <<-OVERWRITE_VERSION7
					s|## -Xms.*|-Xms${memory}g|
					s|## -Xmx.*|-Xmx${memory}g|
				OVERWRITE_VERSION7
                #echo "-XX:+UseCompressedOops" | sudo tee -a "$IN" > /dev/null
                #echo "-XX:MaxGCPauseMillis=200" | sudo tee -a "$IN" > /dev/null
                #echo "-XX:+DisableExplicitGC" | sudo tee -a "$IN" > /dev/null
                
			fi
		fi
	fi 		

		}

main() {
	user_input
	read -ep "Want to continue? [Y/n] :" -n1 LET_IT_GO
	if [[ "${LET_IT_GO,,}" == "y" ]];then
       
		#java_install
		elastic_setup
		if sudo test -f /etc/elasticsearch/elasticsearch.dpkg-dist;then
			echo "You chose not to overwrite existing elasticsearch.yml file..."
		else
			es_config "/etc/elasticsearch/elasticsearch.yml"
		fi
		if sudo test -f /etc/elasticsearch/jvm.options.dpkg-dist ; then
			echo "You chose not to overwrite existing logstash.yml file..."
		else
			jvm_config "/etc/elasticsearch/jvm.options"
		fi

        if [ ! -d "$DATA_PATH" ];then
            sudo mkdir -p "$DATA_PATH"
            sudo chown elasticsearch:elasticsearch "$DATA_PATH"
            sudo chmod 775 "$DATA_PATH"
        fi
        echo "Intallation completed"
        #sudo systemctl daemon-reload
        #sudo systemctl enable elasticsearch.service
        #sudo service elasticsearch start

	else
		echo "Maybe some other time! BYE!"
		exit 1
	fi


}

main







