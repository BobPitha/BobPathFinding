IS_GIT_DIR := $$( if git rev-parse --git-dir > /dev/null 2>&1 ; then echo yes ; else echo no ; fi )
REPOSITORY_ROOT := $$( if [ ${IS_GIT_DIR} = "yes" ] ; then git rev-parse --show-toplevel ; else dirname $(realpath $(firstword $(MAKEFILE_LIST))) ; fi )
REPOSITORY_NAME := $$( basename ${REPOSITORY_ROOT} )
VERSION := $$( if [ ${IS_GIT_DIR} = "yes" ] ; then git rev-parse --short HEAD ; else echo x ; fi )
VERSION_LONG := $$( if [ ${IS_GIT_DIR} = "yes" ] ; then git rev-parse HEAD ; else echo xxx ; fi )

DOCKER_IMAGE_TAG := $$( echo ${REPOSITORY_NAME} | sed 's/^[[:upper:]]/\L&/;s/[[:upper:]]/\L_&/g' )

DOCKER_ROOT_IMAGE := ubuntu:focal
DOCKER_IMAGE := bobp/${DOCKER_IMAGE_TAG}:cpu-${VERSION}
DOCKER_CONTAINER_NAME := ${DOCKER_IMAGE_TAG}
SERVER_USER := go
DOCKER_RUN_USER_ARGS := ${DOCKER_RUN_USER_ARGS} --volume=${REPOSITORY_ROOT}/workspace:/workspace $\
			--volume=${REPOSITORY_ROOT}/shell_state/JetBrains/config-JetBrains:/home/go/.config/JetBrains $\
			--volume=${REPOSITORY_ROOT}/shell_state/JetBrains/local-share-Jetbrains:/home/go/.local/share/JetBrains $\
			--volume=${REPOSITORY_ROOT}/shell_state/java-userprefs:/home/go/.java/.userPrefs
WORKSPACE_PATH := ${REPOSITORY_ROOT}/workspace

build:
	bin/banner Docker build ${DOCKER_IMAGE}
	docker build -t ${DOCKER_IMAGE} \
 		--build-arg FROM_IMAGE=${DOCKER_ROOT_IMAGE} \
 		--build-arg SERVER_USER=${SERVER_USER} \
 		-f Dockerfile-dev .

shell:
	@${REPOSITORY_ROOT}/bin/docker-start.sh ${DOCKER_IMAGE} ${DOCKER_CONTAINER_NAME} "${DOCKER_RUN_USER_ARGS}" "${WORKSPACE_PATH}"
	@${REPOSITORY_ROOT}/bin/docker-shell.sh ${DOCKER_CONTAINER_NAME} ${SERVER_USER} || true

stop:
	docker kill ${DOCKER_CONTAINER_NAME}

clean:
	@echo "removing containers"
	@echo $$(docker ps -q --filter "NAME=${DOCKER_CONTAINER_NAME}")
	@docker rm $$(docker ps -q --filter "NAME=${DOCKER_CONTAINER_NAME}") >/dev/null 2>&1 || echo "   no containers to remove"

