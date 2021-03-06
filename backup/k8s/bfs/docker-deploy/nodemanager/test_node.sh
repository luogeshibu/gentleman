#!/bin/bash
source .env

install(){
  #####################################
  #  modify docker-compose.yaml
  #####################################
  cp ./template/docker-compose-nodemanager.yml ./target/docker-compose-${NODEMANAGER_NAME}.yml
  sed -i "s/\${servicename}/${NODEMANAGER_NAME}/g"  ./target/docker-compose-${NODEMANAGER_NAME}.yml
  sed -i "s/\${TAG}/${TAG}/g"  ./target/docker-compose-${NODEMANAGER_NAME}.yml
  sed -i "s/\${registory}/${RegistryURI}/g"  ./target/docker-compose-${NODEMANAGER_NAME}.yml
  sed -i "s/\${PARTY_ID}/${PARTY_ID}/g"  ./target/docker-compose-${NODEMANAGER_NAME}.yml
  echo "docker-compose-${NODEMANAGER_NAME}.yml modify finished"
  
  #####################################
  #  sql scripts
  #####################################
  cat > ./target/insert_nodemanager.sql <<EOF
use fate_flow;
INSERT INTO server_node (host, port, node_type, status) values ('${NODEMANAGER_NAME}', '9461', 'NODE_MANAGER', 'HEALTHY');
EOF
  
  cat > ./target/delete_nodemanager.sql <<EOF
use fate_flow;
delete from server_node where host='${NODEMANAGER_NAME}';
EOF
  #####################################
  #  deploy nodemanger
  #####################################
  echo "deploy ......"
  scp ./target/docker-compose-${NODEMANAGER_NAME}.yml root@${TARGET_IP}:/data/projects/fate/confs-${PARTY_ID}
  scp ./target/*.sql root@${TARGET_IP}:/data/projects/fate/confs-${PARTY_ID}
  ssh -tt root@${TARGET_IP} << EOF
cd /data/projects/fate/confs-${PARTY_ID}
docker-compose -f docker-compose-${NODEMANAGER_NAME}.yml down
docker-compose -f docker-compose-${NODEMANAGER_NAME}.yml up -d
exit
EOF
  echo "finish!"
  
  #####################################
  #  modify mysql
  #####################################
  if [ ${MODIFY_MYSQL} = "true" ];then
    echo "modify mysql..."
    ssh -tt root@${TARGET_IP} << EOF

cd /data/projects/fate/confs-${PARTY_ID}
MYSQL_CONTAINER=`docker ps --format {{.Names}}|grep mysql`
docker exec -i \$MYSQL_CONTAINER bash -c "mysql -uroot -p${MYSQL_ROOT_PASSWORD}" < ./insert_nodemanager.sql

exit
EOF
  echo "finish!"
  fi
  
}

delete(){
  echo "start delete ..."
  ssh -tt root@$172.16.4.61 << EOF
MYSQL_CONTAINER=`docker ps --format {{.Names}}|grep mysql`
echo \${MYSQL_CONTAINER}
TOTAL=`echo 'select count(*) as total from fate_flow.server_node where host=\${NODEMANAGER_NAME}' > 'test.sql' && docker exec -i $MYSQL_CONTAINER bash -c 'mysql -uroot -proot001' < test.sql | sed -n '2,2p'`
echo \${TOTAL}
exit
EOF

}

showusage(){
echo """
usage:
  --install install nodemanager
  --delete  delete nodemanager
"""
}


main(){
    case $1 in 
    --install)
      install
      ;;
    --delete)
      delete
      ;;
    *)
      echo "wrong parameter"
      showusage
      ;;
    esac
}

main $@
