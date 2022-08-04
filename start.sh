#!/bin/bash

GIT_BASE="git@github.com:KokopelliMusic/"
REPOS=("Kachina" "Tawa" "Wiharu" "spotify_auth_api")
PSQL="postgresql://postgres:postgres@localhost:54322/postgres"

_sl () {
  sleep 0.5
}

# 
#  Command checks
# 

if ! docker info > /dev/null 2>&1; then
  echo "This script uses docker, and it isn't running - please start docker and try again!"
  exit 1
fi

if ! supabase > /dev/null 2>&1; then
  echo "Supabase CLI is not installed, please install this first"
  exit 1
fi

if ! psql --version > /dev/null 2>&1; then
  echo "PostgreSQL is not installed, please install this first"
  exit 1
fi

if [ ! -f settings.conf ]; then
  echo "settings.conf not found! Please copy the settings.conf.example and fill it in!"
  exit 1
fi

# 
# Git cloning
# 

_sl

echo "Cloning all repositories into the current folder"

for repo in ${REPOS[@]}; do
  echo "Cloning" $repo
  git clone $GIT_BASE$repo".git" || git pull
done

# 
# DATABASES (Supabase/Redis)
# 

_sl

echo "Starting Supabase"
if [ ! -d "./supabase" ]; then
  supabase init
fi

if ! supabase start > /dev/null 2>&1; then
  supabase status
fi

_sl

echo "Creating the database"
psql -d $PSQL -f ./Tawa/schema.sql
echo "Populating the database"
psql -d $PSQL -f ./seed.sql

mkdir ./redis
docker start kokopelli_redis || docker run -d --rm --name kokopelli_redis -v "redis:/data" --network="host" -p "6379:6379" redis:alpine
redis_string="redis://localhost:6379"

# 
# Generating config files
# 

echo "Generating settings file for spotify_auth_api"
echo "{
  \"port\": 6969,
  \"route\": \"/spotify/auth\",
  \"client_id\": \"$spotify_client_id\",
  \"client_secret\": \"$spotify_client_secret\"
}" > ./spotify_auth_api/settings.json

_sl

echo "Generating settings file for Kachina"
supabase_anon_key=$(supabase status | sed '7q;d' | awk -F ": " '{print $2}')
supabase_service_key=$(supabase status | sed '8q;d' | awk -F ": " '{print $2}')

echo "
REACT_APP_TAWA_URL=http://localhost:8080/
REACT_APP_SUPABASE_URL=http://localhost:54321/
REACT_APP_SUPABASE_KEY=$supabase_anon_key
REACT_APP_SPOTIFY_SEARCH_STRING=http://localhost:8079/spotify/search?query=
REACT_APP_WEB=true
REACT_APP_SPOTIFY_CLIENT_ID=$spotify_client_id
REACT_APP_SPOTIFY_AUTH=http://localhost:6969/spotify/auth
REACT_APP_BASE_URL=http://localhost:3000
REACT_APP_KOKOPELLI_URL=localhost:3000
REACT_APP_LINK_URL=
REACT_APP_LOCALHOST=true
" > ./Kachina/.env

echo "Generating settings file for Tawa"
echo "
PORT=8080
REDIS_STRING=redis://redis:6379
SUPABASE_URL=http://localhost:54321
SUPABASE_TOKEN=$supabase_service_key
DEV=true
" > ./Tawa/.env

echo "Generating settings file for Wiharu"
echo "  
REACT_APP_SUPABASE_URL=http://localhost:54331
REACT_APP_SUPABASE_KEY=$supabase_anon_key
REACT_APP_TAWA_URL=http://localhost:8080
REACT_APP_TOKEN_REFRESH_URL=http://localhost:6969/spotify/auth/refresh
" > ./Wiharu/.env

echo "Generating settings file for mockify"
echo "
PORT=8079
DEFAULT_PATH=/spotify/
" > ./mockify/.env

_sl

# 
# Docker container builing/running
# 

echo "Building the Spotify auth API"
docker build --tag=kokopelli_spotify_auth ./spotify_auth_api/.

echo "Starting the Spotify auth API"
docker start kokopelli_spotify_auth || docker run -d --rm --name kokopelli_spotify_auth kokopelli_spotify_auth

echo "Building and starting the backend (Tawa)"
cd ./Tawa
npm i
make build-docker-dev
docker start kokopelli_tawa || docker run -d --rm --name kokopelli_tawa -p "8080:8080" -e REDIS_STRING=$redis_string tawa-web-dev
cd ..

echo "Building and starting mockify"
cd ./mockify
npm i
docker build --tag=kokopelli_mockify .
docker start kokopelli_mockify || docker run -d --rm --name kokopelli_mockify -p "8079:8079" kokopelli_mockify
cd ..

_sl

supabase status
echo ""
echo "Finished starting Kokopelli!"
echo ""
echo "    Backend URL: http://localhost:8080"
echo "    Spotify auth API: http://localhost:6969/spotify/auth"
echo "" 
echo "    Login with test@example.com:123456"
echo ""
echo "  To work on the frontends:"
echo ""
echo "    The app (Kachina) is located in ./Kachina"
echo "      cd ./Kachina && make"
echo ""
echo "    The webplayer (Wiharu) is located in ./Wiharu"
echo "      cd ./Wiharu && make"
echo ""
