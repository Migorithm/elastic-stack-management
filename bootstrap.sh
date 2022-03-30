

1.
echo "elasticsearch soft memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
echo "elasticsearch hard memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null

2.
sudo vi /lib/systemd/system/elasticsearch.service
LimitMEMLOCK=infinity


sudo systemctl daemon-reload 


3.
sudo sysctl -a | grep swappiness

4.
sudo sed -i "s/#bootstrap.*/bootstrap.memory_lock: true/" /etc/elasticsearch/elasticsearch.yml 

sudo service elasticsearch start