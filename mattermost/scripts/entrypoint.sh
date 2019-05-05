#! /bin/bash

set -e

# Check env
if [ -z "$POSTGRES_DB" -o -z "$POSTGRES_USER" -o -z "$POSTGRES_PASSWORD" ]; then
	echo >&2 'error: missing POSTGRES_* environment variables'
	exit 1
fi

function createMissingDir {
	if [ ! -d "${1}" ]; then
		echo "Create ${1}"
		mkdir -p "${1}"
		chown $APP_USER:$APP_USER "${1}"
	fi
}

# DB
: ${PG_HOST:="db"}
: ${PG_PORT:="5432"}

# HOME
APP_HOME=/home/$APP_USER

# Dirs
createMissingDir $APP_HOME/data
createMissingDir $APP_HOME/logs
createMissingDir $APP_HOME/cache/letsencrypt
createMissingDir $APP_HOME/plugins
createMissingDir $APP_HOME/client/plugins
createMissingDir $APP_HOME/client/html

# Config
if [ ! -d $APP_HOME/config ]; then

	mkdir $APP_HOME/config
	chown $APP_USER:$APP_USER $APP_HOME/config

	# Copie du template
	cp /opt/mattermost/config/config.json $APP_HOME/config/docker.json

	cat $APP_HOME/config/docker.json | \
		jq ".ComplianceSettings.Directory = \"$APP_HOME/data\"" | \
		jq ".LogSettings.FileLocation = \"$APP_HOME/logs\"" | \
		jq ".FileSettings.Directory = \"$APP_HOME/data\"" | \
		jq ".ServiceSettings.LetsEncryptCertificateCacheFile = \"$APP_HOME/cache/letsencrypt\"" | \
		jq ".PluginSettings.Directory = \"$APP_HOME/plugins\"" | \
		jq ".PluginSettings.ClientDirectory = \"$APP_HOME/client/plugins\"" \
		> $APP_HOME/config/docker.json.tmp && \
	mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json

	# Generate salt
	cat $APP_HOME/config/docker.json | \
		jq ".EmailSettings.InviteSalt = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" | \
		jq ".EmailSettings.PasswordResetSalt = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" | \
		jq ".FileSettings.PublicLinkSalt = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" | \
		jq ".SqlSettings.AtRestEncryptKey = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" \
		> $APP_HOME/config/docker.json.tmp && \
	mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json

fi

# Force db settings
cat $APP_HOME/config/docker.json | \
	jq ".SqlSettings.DriverName = \"postgres\"" | \
 	jq ".SqlSettings.DataSource = \"postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$PG_HOST:$PG_PORT/$POSTGRES_DB?sslmode=disable&connect_timeout=10\"" \
	> $APP_HOME/config/docker.json.tmp && \
mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json

# BUG Compat logs v4.2+
if [ -f $APP_HOME/logs/app.logmattermost.log ]; then
	mv $APP_HOME/logs/app.logmattermost.log $APP_HOME/logs/mattermost.log
	cat $APP_HOME/config/docker.json | \
		jq ".LogSettings.FileLocation = \"$APP_HOME/logs\"" \
		> $APP_HOME/config/docker.json.tmp && \
	mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json
fi

# Config RW
chown $APP_USER:$APP_USER $APP_HOME/config/docker.json

# Fix root.html
if [ -f /opt/mattermost/client/root.html ]; then
	cp -v /opt/mattermost/client/root.html $APP_HOME/client/html/root.html
	ln -vs $APP_HOME/client/html/root.html /opt/mattermost/client/root.html
	chown $APP_USER:$APP_USER /opt/mattermost/client/root.html
fi

# Waiting for db
echo "Waiting for db ..."
while ! nc -w 1 $PG_HOST $PG_PORT 1>/dev/null 2>&1
do
  sleep 5
done

cd "/opt/mattermost"

# Start
if [ ! -z "$@" ]; then
	# Custom command
	exec runuser -u "$APP_USER" -- $@
else
	# Default start
	exec runuser -u "$APP_USER" -- bin/mattermost --config="$APP_HOME/config/docker.json"
fi