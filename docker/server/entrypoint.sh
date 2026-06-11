#!/usr/bin/env sh
set -eu

cat > /app/config.properties <<EOF_CONFIG
server.id=${SERVER_ID:-1}
server.log.display=${SERVER_LOG_DISPLAY:-false}
server.port=${SERVER_PORT:-14444}
db.host=${DB_HOST:-db}
db.port=${DB_PORT:-3306}
db.user=${DB_USER:-nsoz}
db.password=${DB_PASSWORD:-nsoz_password}
db.dbname=${DB_NAME:-nsoz2}
db.driver=${DB_DRIVER:-com.mysql.cj.jdbc.Driver}
db.minconnections=${DB_MIN_CONNECTIONS:-5}
db.maxconnections=${DB_MAX_CONNECTIONS:-20}
db.connectionTimeout=${DB_CONNECTION_TIMEOUT:-300000}
db.leakDetectionThreshold=${DB_LEAK_DETECTION_THRESHOLD:-300000}
db.idleTimeout=${DB_IDLE_TIMEOUT:-120000}
mongodb.host=${MONGODB_HOST:-mongo}
mongodb.port=${MONGODB_PORT:-27017}
mongodb.dbname=${MONGODB_DBNAME:-admin}
mongodb.user=${MONGODB_USER:-root}
mongodb.password=${MONGODB_PASSWORD:-root_password}
websocket.host=${WEBSOCKET_HOST:-ws://127.0.0.1}
websocket.port=${WEBSOCKET_PORT:-8020}
game.upgrade.percent.add=${GAME_UPGRADE_PERCENT_ADD:-10}
game.store.discount=${GAME_STORE_DISCOUNT:-0}
game.shinwa.active=${GAME_SHINWA_ACTIVE:-true}
game.shinwa.fee=${GAME_SHINWA_FEE:-50000}
game.shinwa.max=${GAME_SHINWA_MAX:-10000}
game.shinwa.player.max=${GAME_SHINWA_PLAYER_MAX:-20}
game.arena.active=${GAME_ARENA_ACTIVE:-true}
game.login.limit=${GAME_LOGIN_LIMIT:-10}
game.quantity.display.max=${GAME_QUANTITY_DISPLAY_MAX:-30000}
game.data.version=${GAME_DATA_VERSION:-120}
game.item.version=${GAME_ITEM_VERSION:-120}
game.map.version=${GAME_MAP_VERSION:-120}
game.skill.version=${GAME_SKILL_VERSION:-120}
threadPoolSize=${THREAD_POOL_SIZE:-100}
scheduledPoolSize=${SCHEDULED_POOL_SIZE:-40}
open.vxmm=${OPEN_VXMM:-true}
game.event=${GAME_EVENT:-com.nsoz.event.Halloween}
client.data.size.max=${CLIENT_DATA_SIZE_MAX:-2048}
game.isTest=${GAME_IS_TEST:-false}
EOF_CONFIG

rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 1280x1024x24 -nolisten tcp &
export DISPLAY=:99

exec java -server -Dfile.encoding=UTF-8 -Xms${JAVA_XMS:-512m} -Xmx${JAVA_XMX:-2g} -jar /app/app.jar
