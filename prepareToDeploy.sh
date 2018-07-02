#!/bin/bash

set -e

bold=$(tput bold)
normal=$(tput sgr0)
echoBold () {
	echo "${bold}${1}${normal}"
}
confirmContinue () {
	read -p "${1} (y/n) " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit
	fi
}


# setup
# note that front-end is not in here
# this is because it does not run in a container on the server;
# it's sole purpose is to create static js/html/css/etc. code
# that the server container will upload
BUILD_IMAGES=('api' 'cron' 'db-worker' 'server')

DEFAULT='.env'
read -p "environment file: (${DEFAULT}): " ENV_FILE
ENV_FILE=${ENV_FILE:-${DEFAULT}}

. ${ENV_FILE}
if [[ -z ${IMAGE_PREFIX} ]]; then
	echo "${bold}Warning!${normal} IMAGE_PREFIX is not set in the environment file"
	echo "	This means the docker-compose file might not use the correct images generated by this script"
	confirmContinue "are you sure you wish to continue?"
fi
if [[ -z ${IMAGE_TAG} ]]; then
	echo "${bold}Warning!${normal} IMAGE_TAG is not set in the environment file"
	echo "	This means the docker-compose file might not use the correct images generated by this script"
	confirmContinue "are you sure you wish to continue?"
fi


DEFAULT=${IMAGE_PREFIX}
read -p "docker repo (${DEFAULT}): " DOCKER_REPO
DOCKER_REPO=${DOCKER_REPO:-${DEFAULT}}

DEFAULT="${IMAGE_TAG}"
read -p "tag to give new images on upload (${DEFAULT}): " DOCKER_LABEL
DOCKER_LABEL=${DOCKER_LABEL:-${DEFAULT}}

DEFAULT='docker-compose.production.yml'
read -p "docker compose file (${DEFAULT}): " DOCKER_COMPOSE
DOCKER_COMPOSE=${DOCKER_COMPOSE:-${DEFAULT}}

DEFAULT="$(basename -s '.yml' ${DOCKER_COMPOSE}).noEnvDependency.yml"
read -p "new compose file with substituted env variables (${DEFAULT}): " DOCKER_COMPOSE_NEW
DOCKER_COMPOSE_NEW=${DOCKER_COMPOSE_NEW:-${DEFAULT}}

DEFAULT='front-end/dist'
read -p "dist web folder compiled location (${DEFAULT}): " PUB_WEB_SRC
PUB_WEB_SRC=${PUB_WEB_SRC:-${DEFAULT}}

DEFAULT='server/html'
read -p "public web folder destination (${DEFAULT}): " PUB_WEB_DST
PUB_WEB_DST=${PUB_WEB_DST:-${DEFAULT}}

# explain
echoBold "will build images from:"
for i in "${BUILD_IMAGES[@]}"; do
	echo "	${i}"
done
echoBold "will compile front-end (run 'node compile.js') from ${normal}front-end${bold} folder"
echoBold "will copy compiled web code from ${normal}${PUB_WEB_SRC} ${bold}to${normal} ${PUB_WEB_DST}"
echoBold "will DELETE everything in api/controllers, db-worker/models, db-worker/migrations db-worker/seeds, front-end/src/quizzes, directories in cron/scripts"

echo
confirmContinue "continue ?"

######################## start ########################
# clean
echoBold "cleaning quiz info imported from quizzes"
rm -rf ./api/controllers/*/
rm -rf ./db-worker/models/*/
rm -rf ./db-worker/migrations/*/
rm -rf ./db-worker/seeds/*/
rm -rf ./front-end/src/quizzes/*/
rm -rf ./cron/scripts/*/


# move user specific quizzes to appropriate locations
echoBold "moving back new quizzes from quizzes to appropriate locations"
cd ./quizzes/quizzes/
# might not have all things for cp
set +e
for quiz in */; do
	cp -r "${quiz}api_controllers/"* ../../api/controllers/

	mkdir "../../cron/scripts/${quiz}"
	cp -r "${quiz}cron_scripts/scripts/"*/* "../../cron/scripts/${quiz}"
	cat "${quiz}cron_scripts/crontab.txt" >> ../../cron/crontab

	mkdir "../../db-worker/models/${quiz}"
	cp "${quiz}db_models/"* "../../db-worker/models/${quiz}"

	mkdir "../../db-worker/migrations/${quiz}"
	cp -r "${quiz}db_migrations/"* "../../db-worker/migrations/${quiz}"

	mkdir "../../db-worker/seeds/${quiz}"
	cp -r "${quiz}db-seeds/"* "../../db-worker/seeds/${quiz}"

	mkdir "../../front-end/src/quizzes/${quiz}"
	cp -r "${quiz}quiz_page/"* "../../front-end/src/quizzes/${quiz}"
	############################################
	# add route to routes in core/routes.js
	# and link in quizzes page
	############################################
	
done
set -e
cd ../..
exit

# compile front-end
echoBold "compiling from front-end"
cd front-end
# node compile.js
cd ..

# copy compiled files
echoBold "copying web files"
cp -rf "./${PUB_WEB_SRC}" "./${PUB_WEB_DST}"

# build all docker images
for i in "${BUILD_IMAGES[@]}"; do
	echoBold "building ${i}"
	docker build -t "${DOCKER_REPO}/pushkin-${i}" -t "${DOCKER_REPO}/pushkin-${i}:${DOCKER_LABEL}" "${i}/"
	echoBold "finished building ${i}"
done


# push to dockerhub
echoBold "pushing to dockerhub"
for i in "${BUILD_IMAGES[@]}"; do
	echoBold "pushing ${i}"
	docker push "${DOCKER_REPO}/pushkin-${i}"
	docker push "${DOCKER_REPO}/pushkin-${i}:${DOCKER_LABEL}"
	echoBold "finished pushing ${i}"
done


# remove .env variables > docker-compose.production.noEnvDependency.yml
echoBold "subsituting docker compose file environment references"
set -a
. $ENV_FILE
set +a
cat $DOCKER_COMPOSE | envsubst > $DOCKER_COMPOSE_NEW


# done
echoBold "preparation complete"









