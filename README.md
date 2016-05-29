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
	  image: postgres:9.5
	  env_file: mattermost.env

## Apache proxy

	ProxyPreserveHost On
	RewriteEngine     On

	RewriteCond %{REQUEST_URI}  ^/api/v3/users/websocket [NC,OR]
	RewriteCond %{HTTP:UPGRADE} ^WebSocket$              [NC,OR]
	RewriteCond %{HTTP:CONNECTION} ^Upgrade$             [NC]
	RewriteRule .* ws://127.0.0.1:8065%{REQUEST_URI}     [P,QSA,L]

	RewriteCond %{DOCUMENT_ROOT}/%{REQUEST_FILENAME}     !-f
	RewriteRule .* http://127.0.0.1:8065%{REQUEST_URI}   [P,QSA,L]

	# HTTPS
	RequestHeader set X-Forwarded-Proto "https"
	Header set Strict-Transport-Security "max-age=31536000"

	# Prevent apache from sending incorrect 304 status updates
	RequestHeader unset If-Modified-Since
	RequestHeader unset If-None-Match

	<Location /api/v3/users/websocket>
	        Require all granted
	        ProxyPassReverse ws://127.0.0.1:8065/api/v3/users/websocket
	        ProxyPassReverseCookieDomain 127.0.0.1 <domain>
	</Location>

	<Location />
	        Require all granted
	        ProxyPassReverse http://127.0.0.1:8065/
	        ProxyPassReverseCookieDomain 127.0.0.1 <domain>
	</Location>
