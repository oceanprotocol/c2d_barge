#!/bin/sh
# remove ready flag until we are done
rm -f /ocean/c2d/ready

#trust registry
cp /certs/registry.crt /usr/local/share/ca-certificates/
update-ca-certificates
#build compute custom images

cd /ocean/
if [ -z "$OPERATOR_SERVICE_IMAGE" ]; then
        echo "no OPERATOR_SERVICE_IMAGE defined"
	if [ -z "$OPERATOR_SERVICE_BRANCH" ]; then
		OPERATOR_SERVICE_BRANCH="main"
                echo "Switch to ${OPERATOR_SERVICE_BRANCH} as default"
	fi
        echo "Cloning op-service and checkout branch ${OPERATOR_SERVICE_BRANCH}"
        git clone https://github.com/oceanprotocol/operator-service.git
        cd ./operator-service
        git checkout $OPERATOR_SERVICE_BRANCH
        echo "docker build -t ${REGISTRY}operator-service:latest ."
	docker build -t "${REGISTRY}operator-service:latest" .
        echo "Pushing ${REGISTRY}operator-service:latest"
	docker push ${REGISTRY}operator-service:latest
        OPERATOR_SERVICE_IMAGE = ${REGISTRY}operator-service:latest
fi

cd /ocean/
if [ -z "$OPERATOR_ENGINE_IMAGE" ]; then
        echo "no OPERATOR_ENGINE_IMAGE defined"
	if [ -z "$OPERATOR_ENGINE_BRANCH" ]; then
		OPERATOR_ENGINE_BRANCH="main"
                echo "Switch to ${OPERATOR_ENGINE_BRANCH} as default"
	fi
        echo "Cloning op-engine and checkout branch ${OPERATOR_ENGINE_BRANCH}"
        git clone https://github.com/oceanprotocol/operator-engine.git
        cd ./operator-engine
        git checkout $OPERATOR_ENGINE_BRANCH
        echo "docker build -t ${REGISTRY}operator-engine:latest ."
	docker build -t "${REGISTRY}operator-engine:latest" .
        echo "Pushing ${REGISTRY}operator-engine:latest"
	docker push ${REGISTRY}operator-engine:latest
        OPERATOR_ENGINE_IMAGE = ${REGISTRY}operator-engine:latest
fi

cd /ocean/
if [ -z "$POD_CONFIGURATION_IMAGE" ]; then
        echo "no POD_CONFIGURATION_IMAGE defined"
	if [ -z "$POD_CONFIGURATION_BRANCH" ]; then
		POD_CONFIGURATION_BRANCH="main"
                echo "Switch to ${POD_CONFIGURATION_BRANCH} as default"
	fi
        echo "Cloning pod-configuration and checkout branch ${POD_CONFIGURATION_BRANCH}"
        git clone https://github.com/oceanprotocol/pod-configuration.git
        cd ./pod-configuration
        git checkout $POD_CONFIGURATION_BRANCH
        echo "docker build -t ${REGISTRY}pod-configuration:latest ."
	docker build -t "${REGISTRY}pod-configuration:latest" .
        echo "Pushing ${REGISTRY}pod-configuration:latest"
	docker push ${REGISTRY}pod-configuration:latest
        POD_CONFIGURATION_IMAGE = ${REGISTRY}pod-configuration:latest
fi


cd /ocean/
if [ -z "$POD_PUBLISHING_IMAGE" ]; then
        echo "no POD_CONFIGURATION_IMAGE defined"
	if [ -z "$POD_PUBLISHING_BRANCH" ]; then
		POD_PUBLISHING_BRANCH="main"
                echo "Switch to ${POD_PUBLISHING_BRANCH} as default"
	fi
        echo "Cloning pod-publishing and checkout branch ${POD_PUBLISHING_BRANCH}"
        git clone https://github.com/oceanprotocol/pod-publishing.git
        cd ./pod-publishing
        git checkout $POD_PUBLISHING_BRANCH
        echo "docker build -t ${REGISTRY}pod-publishing:latest ."
	docker build -t "${REGISTRY}pod-publishing:latest" .
        echo "Pushing ${REGISTRY}pod-publishing:latest"
	docker push ${REGISTRY}pod-publishing:latest
        POD_PUBLISHING_IMAGE = ${REGISTRY}pod-publishing:latest
fi

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
kubectl apply -f /ocean/deployments/operator-service/deployment.yaml
kubectl expose deployment operator-api --namespace=ocean-operator --port=8050
kubectl create -f /ocean/deployments/operator-service/expose_service.yaml
# move to op engine
echo "Creating op-engine deployment:"
kubectl config set-context --current --namespace ocean-compute
kubectl apply -f /ocean/deployments/operator-engine/sa.yml
kubectl apply -f /ocean/deployments/operator-engine/binding.yml
kubectl apply -f /ocean/deployments/operator-engine/operator.yml
kubectl create -f /ocean/deployments/operator-service/postgres-configmap.yaml
sleep 5
#wait for op-service to be up
echo "Waiting for op-service deployment, so we can init pgsql" 
kubectl wait -n ocean-operator deploy/operator-api --for=condition=available --timeout 10m 
#initialize op-api 
until $(curl --output /dev/null --silent --head --fail -X POST "http://${KIND_IP}:31000/api/v1/operator/pgsqlinit" -H  "accept: application/json"); do
    printf '.'
    sleep 5
done
echo "C2d is Up & running. Have fun!"
#signal that we are ready
touch /ocean/c2d/ready
while true; do sleep 12 ; done

