# c2d_barge
Tools used to have c2d in barge



##  C2D_KIND
This is a forked version of https://github.com/bsycorp/kind, modified to run in barge (network, ips, etc)
Images are build & pushed manually as oceanprotocol/c2d_barge_kind:latest  (or other tag)

### how to build
  - open a new terminal and run a light barge:  ./start_ocean.sh --no-dashboard --no-aquarius --no-provider
  - once barge is up, do ./build.sh here
  - tag the resulting image :  docker tag XXXXX  oceanprotocol/c2d_barge_kind:latest
  - push it:  docker push oceanprotocol/c2d_barge_kind:latest

## C2D_DOCKER_DEPLOYER
At startup, it waits for c2d_kind to be ready (ie:  k8 status is ready).
Next step is to build or download the c2d images and then deploy them to the k8 cluster
From this folder,  docker image oceanprotocol/c2d_barge_deployer:latest is created by dockerhub
