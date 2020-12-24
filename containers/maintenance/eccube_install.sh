#!/usr/bin/env bash

set -x

TMP_DIR=/tmp
ECCUBE_VER=4.0.5
ECCUBE_FILE=${TMP_DIR}/eccube-${ECCUBE_VER}.tar.gz
DOCROOT_DIR=/var/www/html
PV_DIR=/opt/ec-cube

cd ${TMP_DIR}
curl -O https://downloads.ec-cube.net/src/eccube-${ECCUBE_VER}.tar.gz

if [ -d ${DOCROOT_DIR} ]; then
  rm -rf ${DOCROOT_DIR}
  mkdir -p ${DOCROOT_DIR}
fi

# document root配下に展開
cd ${DOCROOT_DIR}
tar xvzf ${ECCUBE_FILE} --strip-components 1

rm -rf ${DOCROOT_DIR}/composer.json
rm -rf ${DOCROOT_DIR}/composer.lock
rm -rf ${DOCROOT_DIR}/symfony.lock
rm -rf ${DOCROOT_DIR}/app/Plugin
rm -rf ${DOCROOT_DIR}/app/PluginData
rm -rf ${DOCROOT_DIR}/app/template
rm -rf ${DOCROOT_DIR}/html
rm -rf ${DOCROOT_DIR}/var

# link作成
ln -s ${PV_DIR}/.env ${DOCROOT_DIR}/.env
ln -s ${PV_DIR}/composer.json ${DOCROOT_DIR}/composer.json
ln -s ${PV_DIR}/composer.lock ${DOCROOT_DIR}/composer.lock
ln -s ${PV_DIR}/symfony.lock ${DOCROOT_DIR}/symfony.lock
ln -s ${PV_DIR}/app/Plugin ${DOCROOT_DIR}/app/Plugin
ln -s ${PV_DIR}/app/PluginData ${DOCROOT_DIR}/app/PluginData
ln -s ${PV_DIR}/app/template ${DOCROOT_DIR}/app/template
ln -s ${PV_DIR}/html ${DOCROOT_DIR}/html
ln -s ${PV_DIR}/var ${DOCROOT_DIR}/var

# 永続ボリュームへ展開
cd ${PV_DIR}
ARCHIVE_ROOT=$(tar tf ${ECCUBE_FILE} | sort | head -n 1)

if [ ! -f ${PV_DIR}/.env ]; then

  cat << EOF > .env
APP_ENV=${APP_ENV}
APP_DEBUG=${APP_DEBUG}
DATABASE_URL=${DATABASE_URL}
DATABASE_SERVER_VERSION=${DATABASE_SERVER_VERSION}
MAILER_URL=${MAILER_URL}
ECCUBE_AUTH_MAGIC=${ECCUBE_AUTH_MAGIC}
ECCUBE_ADMIN_ROUTE=${ECCUBE_ADMIN_ROUTE}
EOF

  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}composer.json --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}composer.lock --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}symfony.lock --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}app/Plugin --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}app/PluginData --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}app/template --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}html --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}var --strip-components 1

  cd ${DOCROOT_DIR}
  bin/console e:i --no-interaction

else

  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}composer.json --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}composer.lock --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}symfony.lock --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}vendor --strip-components 1
  tar xfz ${ECCUBE_FILE} ${ARCHIVE_ROOT}html --strip-components 1

  cd ${DOCROOT_DIR}
  bin/console cache:clear --no-warmup --env=prod
  bin/console eccube:composer:require-already-installed
  bin/console doctrine:schema:update --force --dump-sql
  bin/console doctrine:migrations:migrate --no-interaction

fi

bin/console cache:clear --no-warmup --env=prod
bin/console cache:warmup --no-optional-warmers --env=prod
composer dump-autoload -o

chown -R www-data:www-data ${PV_DIR}
chown -R www-data:www-data ${DOCROOT_DIR}
