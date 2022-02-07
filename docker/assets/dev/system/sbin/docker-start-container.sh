#!/bin/bash -x

# use the following lines to specify the development user and group
# export SERVER_USER=username
# export SERVER_GROUP=groupname

/sbin/docker-setup-user.sh
/sbin/docker-start-sleep-loop.sh
