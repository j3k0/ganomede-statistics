restify = require 'restify'
redis = require 'redis'
Task = require 'data.task'
Maybe = require 'data.maybe'
alkindi = require 'alkindi'

Storage = require './storage'
log = require '../log'

module.exports = exports = {}

clone = exports.clone = (obj) -> JSON.parse(JSON.stringify(obj))

extend = exports.extend = (object, properties) ->
  ret = {}
  for key, val of object
    ret[key] = val
  for key, val of properties
    ret[key] = val
  ret

sendError = exports.sendError = (send, next) -> (err) ->
  log.error err
  send err
  next()

sendSuccess = exports.sendSuccess = (send, next) -> (data) ->
  log.info data
  send data
  next()

createStorage = exports.createStorage = (config) ->
  new Storage(
    redis.createClient(config.redis.port, config.redis.host)
    config.redis.prefix
  )

# String -> String -> String
fullType = exports.fullType = (gameType, gameVersion) ->
  if gameType && gameVersion
  then "#{gameType}/#{gameVersion}"
  else null

#
# Middlewares
#

# Format request parameters
# req -> res -> next -> Task(Params)
getParams = exports.getParams =
(req, res, next) -> new Task (reject, resolve) ->
  resolve
    gameType: fullType req?.params?.gameType, req?.params?.gameVersion
    username: req?.params?.username
    params: req:req, res:res, next:next

# Params -> Task(Params)
checkParams = exports.checkParams =
(params) -> new Task (reject, resolve) ->
  if !params || !params.gameType || !params.username
  then reject new restify.InvalidContentError('invalid content')
  else resolve params

# Storage -> Params -> Task(Archive)
loadArchive = exports.loadArchive =
(storage) -> (params) -> new Task (reject, resolve) ->
  storage.getArchive params.gameType, params.username, (err, data) ->
    if err then reject err
    else resolve extend params, archive:data

# Archive -> Stats
getStats = exports.getStats =
(data) -> extend data, stats:alkindi.getPlayerStats(data.archive)

debug = exports.debug =
(title) -> (data) ->
  log.info title:title, extend(data, params:true)
  data

performIO = exports.performIO = (res, next, io) ->
  io.fork(
    sendError(res.send.bind(res), next),
    sendSuccess(res.send.bind(res), next)
  )


# vim: ts=2:sw=2:et:
