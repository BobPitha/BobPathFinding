#!/bin/bash -x

# Do this first to set the group ID properly manually (setting the ownership first won't work)
groupmod -g $HOST_GID $SERVER_GROUP

# Now set the ownership by name recursively
chown -R "$SERVER_USER:$SERVER_GROUP" /home/$SERVER_USER/

# do this last. After you do this, you cannot sudo again in this shell. You must
# start another shell within this one.
usermod -u $HOST_UID $SERVER_USER

touch /.docker-setup-user-complete
