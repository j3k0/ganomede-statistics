restify = require 'restify'
Task = require 'data.task'
alkindi = require 'alkindi'

log = require '../log'
extend = require('../toolbox').extend
taskFromNode = require('../toolbox').taskFromNode

#
# Implicit types used by this module
#
# Storage: (see ./storage.coffee)
#
# ShortType: String
# Version: String
# FullType: String
# Username: String
#
# RequestParams: {
#   gameType: ShortType
#   gameVersion: Version
#   username: Username
# }
#
# Params: {
#   gameType: FullType
#   username: Username
# }
#
# Archive: {
#   gameType: FullType
#   username: Username
#   archive: PlayerArchive (see alkindi)
# }
#
# Stats: {
#   gameType: FullType
#   username: Username
#   archive: PlayerArchive (see alkindi)
#   stats: PlayerStats (see alkindi)
# }
#
# ResponseArchive: PlayerArchive (see alkindi)
#
# ResponseStats: PlayerStats (see alkindi)
#

module.exports = exports = {}

# Build full game type from short type and version.
#
# ShortType -> Version -> FullType
fullType = exports.fullType = (gameType, gameVersion) ->
  if gameType && gameVersion
  then "#{gameType}/#{gameVersion}"
  else null

# Format request parameters
#
# RequestParams -> Task(Params)
readParams = exports.readParams =
(params) -> new Task (reject, resolve) ->
  resolve
    gameType: fullType params?.gameType, params?.gameVersion
    username: params?.username

# Params -> Task(Params)
checkParams = exports.checkParams =
(params) -> new Task (reject, resolve) ->
  if !params || !params.gameType || !params.username
  then reject new restify.InvalidContentError('invalid content')
  else resolve params

# Storage -> Params -> Task(Archive)
loadArchive = exports.loadArchive =
(storage) -> (params) -> new Task (reject, resolve) ->
  storage.getArchives params.gameType, params.username, (err, data) ->
    if err then reject err
    else resolve extend params, archive:data

# Storage -> Params -> Rank
getRank = exports.getRank =
(storage) -> (params) -> new Task (reject, resolve) ->
  storage.getRank params.gameType, params.username,
    taskFromNode(reject, resolve)

# Trace A to the console.
#
# String -> A -> A
debug = exports.debug = (title) -> (data) ->
  log.info title:title, extend(data, params:true)
  data

# RequestParams -> Task(Archive)
archiveRequest = exports.archiveRequest = (storage, params) ->
  readParams params
  .chain checkParams
  .chain loadArchive(storage)

# RequestParams -> Task(ResponseArchive)
archiveEndpoint = exports.archiveEndpoint = (storage, params) ->
  archiveRequest storage, params
  .map   (data) -> data.archive

# RequestParams -> Task(ResponseArchive)
rankEndpoint = exports.rankEndpoint = (storage, params) ->
  readParams params
  .chain checkParams
  .chain getRank(storage)
  .map (rank) ->
    rank: if (rank == null || rank < 0) then 0 else (1 + rank)

# vim: ts=2:sw=2:et:
