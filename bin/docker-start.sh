#!/bin/bash

# Handle arguments
if [[ "$#" -lt 2 ]]; then
  echo "ERROR: missing arguments."
  exit 1
fi

readonly IMAGE="$1"
readonly CONTAINER_NAME="$2"
if [[ "$#" -ge 3 ]]; then
  readonly USER_ARGS="$3"
fi
if [[ "$#" -ge 4 ]]; then
  readonly WORKSPACE_PATH="$4"
fi

readonly DATABASE_DOCKER_COMPOSE_NETWORK="${CONTAINER_NAME}-network"
readonly DATABASE_DOCKER_COMPOSE_VOLUME="${CONTAINER_NAME}-volume"

# if docker container ${CONTAINER_NAME} is not running... start one
running_container_id=`docker ps --format "{{.ID}}" --filter name=${CONTAINER_NAME}`
if [[ -z "${running_container_id}" ]]; then

  # specialize the docker run args for the host hardware
  arch_args=""
  if [ "${PP_GRAPHICS_HARDWARE,,}" = "nvidia" ]; then
    arch_args="--gpus all"
  fi

  # check that that docker image of interest is already built
  if [ -z $(docker images -q ${IMAGE}) ]; then
      echo "Attemping to run image $IMAGE, but it does not exist locally. You probably need to run 'make build' first."
      exit 1
  fi

  # Add workspace directory and any links
  if [[ -d "${WORKSPACE_PATH}" ]]; then
    echo "Workspace path exists"
    workspace_mounts="--volume=${WORKSPACE_PATH}:/workspace"

    for symbolic_link in `find ${WORKSPACE_PATH} -maxdepth 1 -type l`; do
      slink=`readlink ${symbolic_link}`
      echo "found symbolic link in workspace: ${symbolic_link} -> ${slink}"
      abs="$( cd "$(dirname "${slink}")"; pwd)/$(basename "${slink}")"

      workspace_mounts="${workspace_mounts} --volume="${abs}":/workspace/`basename ${symbolic_link}`"
    done
  fi

  # setup x-windows to allow docker to display GUIs
  readonly XSOCK=/tmp/.X11-unix
  readonly XAUTH=$(mktemp /tmp/.docker.xauth.XXXXXX)
  touch $XAUTH
  xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

  if [[ -z `docker network ls --filter NAME=${DATABASE_DOCKER_COMPOSE_NETWORK} -q` ]]; then
    echo "Starting ${DATABASE_DOCKER_COMPOSE_NETWORK} network"
    docker network create ${DATABASE_DOCKER_COMPOSE_NETWORK}
  fi

  if [[ -z `docker volume ls --filter NAME=${DATABASE_DOCKER_COMPOSE_VOLUME} -q` ]]; then
    echo "Creating volume ${DATABASE_DOCKER_COMPOSE_VOLUME}"
    docker volume create ${DATABASE_DOCKER_COMPOSE_VOLUME}
  fi

  # if there's a docker-compose.yml, start it.
  if [ -e docker-compose.yml ]; then
    echo "Starting database containers"
    docker-compose up > docker-compose.log &
  fi

  echo "Starting a new ${CONTAINER_NAME} docker container from image ${IMAGE}"
  readonly HOST_UID=$(id -u)
  readonly HOST_GID=$(id -g)
  ( set -x;

  docker run \
    --privileged \
    --rm \
    --tty \
    --detach \
    --network host \
    -p 610:610 \
    -p 8181:8181 \
    -p 4369:4369 \
    -p 5672:5672 \
    -p 5671:5671 \
    --expose 2000 \
    --name ${CONTAINER_NAME} \
    --hostname ${CONTAINER_NAME} \
    --env="DISPLAY" \
    --env="XAUTHORITY=${XAUTH}" \
    --env="QT_X11_NO_MITSHM=1" \
    --env="HOST_UID=$HOST_UID" \
    --env="HOST_GID=$HOST_GID" \
    --volume=$XSOCK:$XSOCK:rw \
    --volume=$XAUTH:$XAUTH:rw \
    $USER_ARGS \
    $workspace_mounts \
    $arch_args \
    $IMAGE \
    || exit 1

  )

else
  running_image_id=`docker inspect ${running_container_id} --format "{{.Image}}"`
  latest_image_id=`docker inspect $IMAGE --format "{{.Id}}"`

  if [[ "${running_image_id}" != "${latest_image_id}" ]]; then
    echo "$(tput setaf 202)***** A container for ${CONTAINER_NAME} is running, but it is not the most recent image."
    echo "$(tput setaf 214)***** You might have built a new image but not restarted your container.$(tput sgr0)"
  fi
fi
