#!/bin/sh
# remove ready flag until we are done
rm -f /ocean/c2d/ready

#trust registry
cp /certs/registry.crt /usr/local/share/ca-certificates/
update-ca-certificates
#build compute custom images
if [ "${WAIT_FOR_C2DIMAGES+set}" = set ] && [ "$WAIT_FOR_C2DIMAGES" = yeah ]; then
  echo "Waitting for images"
  while [ ! -f "/ocean/c2d/imagesready" ]; do
        sleep 2
  done
fi
cd /ocean/

echo "Using ${OPERATOR_SERVICE_IMAGE} for operator-service"
echo "Using ${OPERATOR_ENGINE_IMAGE} for operator-engine"
echo "Using ${POD_CONFIGURATION_IMAGE} for pod-configuration"
echo "Using ${POD_PUBLISHING_IMAGE} for pod-publishing"
#do the replaces
echo "Replacing deployment files to match the above..."
sed -i "s!oceanprotocol/operator-service:latest!$OPERATOR_SERVICE_IMAGE!g" /ocean/deployments/operator-service/deployment.yaml
sed -i "s!oceanprotocol/operator-engine:latest!$OPERATOR_ENGINE_IMAGE!g" /ocean/deployments/operator-engine/operator.yml
sed -i "s!oceanprotocol/pod-configuration:latest!$POD_CONFIGURATION_IMAGE!g" /ocean/deployments/operator-engine/operator.yml
sed -i "s!oceanprotocol/pod-publishing:latest!$POD_PUBLISHING_IMAGE!g" /ocean/deployments/operator-engine/operator.yml
sed -i "s!IPFS_SERVER_URL!${IPFS_GATEWAY}!g" /ocean/deployments/operator-engine/operator.yml
sed -i "s!IPFS_OUTPUT_SERVER_URL!${IPFS_HTTP_GATEWAY}!g" /ocean/deployments/operator-engine/operator.yml
echo "Doing cat /ocean/deployments/operator-service/deployment.yaml for debug purposes..."
cat /ocean/deployments/operator-service/deployment.yaml
echo "#####################################"
echo "Doing cat /ocean/deployments/operator-engine/operator.ymlfor debug purposes..."
cat /ocean/deployments/operator-engine/operator.yml
echo "###########"
echo "Waiting for the k8 config to be ready.."
sleep 60
#wait until config is ready
until $(curl --output /dev/null --silent --head --fail http://${KIND_IP}:10080/config); do
    printf '.'
    sleep 5
done
echo "\nWaiting for the k8 cluster to be ready.."
#wait until k8 is ready
until $(curl --output /dev/null --silent --head --fail http://${KIND_IP}:10080/kubernetes-ready); do
    printf '.'
    sleep 5
done
echo "\nWaiting for the k8 docker to be ready.."
#wait until docker is ready
until $(curl --output /dev/null --silent --head --fail http://${KIND_IP}:10080/docker-ready); do
    printf '.'
    sleep 5
done
echo "\nConfiguring kubectl"
#get kubectl config
wget http://${KIND_IP}:10080/config
mkdir ~/.kube/
cp config ~/.kube/config
echo "Current k8 nodes:"
kubectl get nodes
kubectl create ns ocean-operator
kubectl create ns ocean-compute
echo "Creating op-service deployment:"
kubectl config set-context --current --namespace ocean-operator
kubectl create -f /ocean/deployments/operator-service/postgres-configmap.yaml
kubectl create -f /ocean/deployments/operator-service/postgres-storage.yaml
kubectl create -f /ocean/deployments/operator-service/postgres-deployment.yaml
kubectl create -f /ocean/deployments/operator-service/postgresql-service.yaml
sleep 5
#wait for pgsql to be up
kubectl wait -n ocean-operator deploy/postgres --for=condition=available --timeout 10m
kubectl apply -f /ocean/deployments/operator-service/deployment.yaml
kubectl expose deployment operator-api --namespace=ocean-operator --port=8050
kubectl create -f /ocean/deployments/operator-service/expose_service.yaml
sleep 5
#wait for op-service to be up
echo "Waiting for op-service deployment, so we can init pgsql"
kubectl wait -n ocean-operator deploy/operator-api --for=condition=available --timeout 10m
sleep 10
#initialize op-api
until $(curl --output /dev/null --silent --head --fail -X POST "http://${KIND_IP}:31000/api/v1/operator/pgsqlinit" -H  "accept: application/json"); do
    printf '.'
    sleep 5
done
echo "Pgsql initialized"
# move to op engine
echo "Creating op-engine deployment:"
kubectl config set-context --current --namespace ocean-compute
kubectl create -f /ocean/deployments/operator-service/postgres-configmap.yaml
kubectl apply -f /ocean/deployments/operator-engine/sa.yml
kubectl apply -f /ocean/deployments/operator-engine/binding.yml
kubectl apply -f /ocean/deployments/operator-engine/operator.yml
sleep 5
#wait for op-engine to be up
kubectl wait -n ocean-compute deploy/ocean-compute-operator --for=condition=available --timeout 10m
echo "C2d is Up & running. Have fun!"
#signal that we are ready
touch /ocean/c2d/ready
while true; do sleep 12 ; done

