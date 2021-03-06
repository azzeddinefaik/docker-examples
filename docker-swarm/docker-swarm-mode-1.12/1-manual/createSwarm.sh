#!/bin/bash
set -e

# default driver. specify parameter amazonec2 to create this in cloud.

echo "--------------------------------"
echo "SWARM CREATION SCRIPT"
echo "(to be run from Cygwin or Docker Quickstart Terminal)"
echo "Usage:"
echo "$0 :  create docker swarm using virtualbox VMs"
echo "$0 amazonec2: create swarm in Amazon AWS"
echo "-------------------------------"

if [[ "$#" == 0 ]]; then
  DRIVER="virtualbox"
else
  DRIVER=$1
fi

doAWSChecks() {
  echo "-- initial checks..."
  errors=false
  for var in  AWS_ACCESS_KEY \
              AWS_SECRET_KEY \
              AWS_VPC_ID \
              AWS_DEFAULT_REGION \
              AWS_KEYPAIR_NAME \
              AWS_SSH_KEYPATH \
              AWS_DEFAULT_ZONE \
              AWS_SECURITYGROUP; do
    if [[ "${!var}" == "" ]]; then
      echo "ERROR: $var is not set! Did you set the variable in setenv.sh?"
      errors=true
    fi
  done
  if $errors; then
    echo "Please fix the above errors and try again" \
    && exit 1
  fi
}

# common amazon ec2 options
if [[ "$DRIVER" == "amazonec2" ]]; then
    . setenv.sh
    doAWSChecks
    COMMON_OPTS=" --amazonec2-region $AWS_DEFAULT_REGION \
                  --amazonec2-zone $AWS_DEFAULT_ZONE \
                  --amazonec2-vpc-id $AWS_VPC_ID \
                  --amazonec2-keypair-name $AWS_KEYPAIR_NAME \
                  --amazonec2-ssh-keypath $AWS_SSH_KEYPATH \
                  --amazonec2-security-group $AWS_SECURITYGROUP "
elif [[ "$DRIVER" == "virtualbox" ]]; then
    COMMON_OPTS=""
else
  echo "unsupported driver: $DRIVER" && exit 1
fi

echo "---- using driver $DRIVER"
# remove previous machines.
echo "---- removing any previous docker-machines"
docker-machine rm -f manager0
docker-machine rm -f worker0
docker-machine rm -f worker1

echo "---- creating docker machines manager0, worker0, worker1"
docker-machine create -d $DRIVER $COMMON_OPTS manager0
docker-machine create -d $DRIVER $COMMON_OPTS worker0
docker-machine create -d $DRIVER $COMMON_OPTS worker1


eval $(docker-machine env manager0)
# get ip of manager0
MANAGER0_IP=$(docker-machine ip manager0)
echo "---- creating swarm manager; machine ip $MANAGER0_IP"
docker swarm init --advertise-addr $MANAGER0_IP

# get manager and worker tokens
MANAGER_TOKEN=$(docker swarm join-token -q manager)
WORKER_TOKEN=$(docker swarm join-token -q worker)

WORKER_JOIN_CMD="docker swarm join --token $WORKER_TOKEN $MANAGER0_IP:2377"

echo "---- joining worker0, worker1 to swarm"
eval $(docker-machine env worker0)
eval $WORKER_JOIN_CMD
eval $(docker-machine env worker1)
eval $WORKER_JOIN_CMD
