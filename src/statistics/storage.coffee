log = require '../log'
redis = require 'redis'

PREFIX_SEPARATOR = ':'

class Storage
  constructor: (redis, prefix) ->
    @redis = redis
    @prefix = prefix

  key: (gameType, parts...) ->
    [@prefix, gameType].concat(parts).join(PREFIX_SEPARATOR)

  # Type -> Username -> GetArchiveCallback
  getArchives: (type, username, callback) ->
    @redis.zrange [@key(type, username), 0, -1], (err, reply) ->
      if err
        log.error 'redis.getArchives() failed',
          err: err
          id: id
        callback err
      else
        callback null, JSON.parse(reply)

  # Type -> Username -> GameOutcome -> Void
  saveArchive: (type, username, game) ->
    @redis.zadd [
      @key(type, username),
      Math.round(game.date),
      JSON.stringify(game)
    ]

# StorageConfig -> Storage
Storage.create = exports.createStorage = (config) ->
  new Storage(
    redis.createClient(config.port, config.host)
    config.prefix
  )

module.exports = Storage

