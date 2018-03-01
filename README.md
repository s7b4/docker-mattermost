# Docker Mattermost

## Variables d'environnement (mattermost.env)

* POSTGRES_DB: Nom de la base postgres
* POSTGRES_USER: Nom de l'utilisateur postgres
* POSTGRES_PASSWORD: Mot de passe de POSTGRES_USER
* PG_HOST: Nom d'hôte du serveur postgres (def: db)
* PG_PORT: Port du serveur postgres (def: 5432)

## Compose

	app:
	  build: mattermost
	  links:
	    - db:db
	  ports:
	    - "8065:8065"
	  env_file: mattermost.env
	  # Upgrade params
	  # command: /bin/bash
	  # tty: true
	  # stdin_open: true


	db:
	  image: postgres:10.1
	  env_file: mattermost.env

## Apache proxy

	ProxyPreserveHost On
	RewriteEngine     On

	RewriteCond %{HTTP:Upgrade} websocket                [NC]
	RewriteCond %{HTTP:Connection} Upgrade               [NC]
	RewriteRule .* ws://<ip>:<port>%{REQUEST_URI}        [P,QSA,L]

	ProxyPass / http://<ip>:<port>/
	ProxyPassReverse / http://<ip>:<port>/
	ProxyPassReverseCookieDomain <ip> <fqdn>

	# HTTPS
	RequestHeader set X-Forwarded-Proto "https"
	Header set Strict-Transport-Security "max-age=31536000"

	# Prevent apache from sending incorrect 304 status updates
	RequestHeader unset If-Modified-Since
	RequestHeader unset If-None-Match
