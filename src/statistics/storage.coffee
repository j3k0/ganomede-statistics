log = require '../log'
redis = require 'redis'

PREFIX_SEPARATOR = ':'

class Storage
  constructor: (redis, prefix) ->
    @redis = redis
    @prefix = prefix

  key: (gameType, parts...) ->
    [@prefix, gameType].concat(parts).join(PREFIX_SEPARATOR)

  getArchive: (type, username, callback) ->
    callback null, []
    #@_moves(@multi(), id).exec (err, replies) ->
    #  if (err)
    #    log.error 'Redis.moves() failed',
    #      err: err
    #      id: id
    #    return callback(err)
    #
    #  moves = replies[0]
    #  callback(null, moves.map (move) -> JSON.parse(move))

#
# StorageConfig -> Storage
#
# StorageConfig: {
#   host: String
#   port: String
#   prefix: String
# }
#
Storage.create = exports.createStorage = (config) ->
  new Storage(
    redis.createClient(config.port, config.host)
    config.prefix
  )

module.exports = Storage

