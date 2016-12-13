# Types used by the statistics module
#

types = {}

error = (data, msg) ->
  err = new Error(msg)
  err.data = data
  err.toString = () ->
    error.message + "\ndata: " + JSON.stringify(data)
  err

#
# Type checking methods
#

baseType = types.baseType = (username, type) -> (x) ->
  if typeof x != type
    throw error(x, username + ' should be a ' + type + ', not a ' + typeof x)
  x

objectOf = types.objectOf = (username, def) -> (obj) ->
  baseType username, obj, 'object'
  try
    for key, subtype of def
      subtype obj[key]
  catch err
    throw error(obj, username + '.' + err.message)
  obj

arrayOf = types.arrayOf = (username, subtype) -> (xs) ->
  baseType username, xs, 'object'
  baseType username + '.forEach', xs.forEach, 'function'
  try
    xs.forEach (x, index) -> subtype x
  catch err
    throw error(xs, username + '.' + err.message)
  xs

#
# Types definitions
#

# GameType: String
types.gameType = baseType 'GameType', 'string'

# Username: String
types.username = baseType 'Username', 'string'

# Timestamp: Number
types.timestamp = baseType 'Timestamp', 'number'

# PlayerScore: {
#   username: Username,
#   score: Int
# }
types.playerScore = objectOf 'PlayerScore',
  username: types.username
  score: baseType 'Int', 'number'

# Game: {
#   id: String
#   date: Timestamp,
#   type: GameType,
#   gameOverData: {
#     players: Array<PlayerScore>
#   }
# }
types.game = objectOf 'Game',
  id: baseType 'String', 'string'
  date: types.timestamp
  type: types.gameType
  gameOverData: objectOf 'Game.gameOverData',
    players: arrayOf '[PlayerScore]', types.playerScore

# GetArchivesCallback: Error -> Array<GameOutcome> -> Void
types.getArchivesCallback = baseType 'GetArchivesCallback', 'function'

# GameOutcome: {
#   game: {
#     date: Timestamp,
#     id: String,
#     players: Array<PlayerScore>
#   }
#   outcome: {
#     newLevel: Int
#   }
# }
types.gameOutcome = objectOf 'GameOutcome',
  game: objectOf 'game',
    date: types.timestamp
    id: baseType 'String', 'string'
    players: arrayOf '[PlayerScore]', types.playerScore
  outcome: objectOf 'outcome',
    newLevel: baseType 'Int', 'number'

# PlayerArchive: = {
#   username: Username,
#   games: Array<GameOutcome>
# }
types.playerArchive = objectOf 'PlayerArchive',
  username: types.username
  games: arrayOf 'games', types.gameOutcome

# GameWithArchives: {
#   game: Game
#   archives: Array<PlayerArchive>
#   index: Int
# }
types.gameWithArchives = objectOf 'GameWithArchives',
  game: types.game
  archives: arrayOf '[PlayerArchive]', types.playerArchive
  index: baseType 'Index', 'number'

# PlayerGameOutcome: {
#   username: Username
#   type: GameType
#   game: GameOutcome
# }
types.playerGameOutcome = objectOf 'PlayerGameOutcome',
  username: types.username
  type: types.gameType
  game: types.gameOutcome

# GameRank: {
#   game: {
#     id: String,
#     date: Timestamp,
#     players: Array<PlayerScore>
#   }
#   outcome: {
#     newLevel: Int
#     newRank: Int
#   }
# }
types.gameRank = objectOf 'GameRank',
  game: objectOf 'GameRank.game',
    id: baseType 'String', 'string'
    date: types.timestamp
    players: arrayOf '[PlayerScore]', types.playerScore
  outcome: objectOf 'GameRank.outcome',
    newLevel: baseType 'Int', 'number'
    newRank: baseType 'Int', 'number'

# PlayerGameRank: {
#   username: Username
#   type: GameType
#   game: GameRank
# }
types.playerGameRank = objectOf 'PlayerGameRank',
  username: types.username
  type: types.gameType
  game: types.gameRank

# StorageConfig: {
#   host: String
#   port: String
#   prefix: String
# }
types.storageConfig = objectOf 'StorageConfig',
  host: baseType 'String', 'string'
  port: baseType 'String', 'string'
  prefix: baseType 'String', 'string'

# SeqNumber: Int
types.seqNumber = baseType 'Int', 'number'

# GamesBody: {
#   last_seq: SeqNumber
#   results: Array<Game>
# }
types.gamesBody = objectOf 'GamesBody',
  last_seq: types.seqNumber
  results: arrayOf '[Game]', types.game

# ProcessOutcome: {
#   last_seq: SeqNumber
# }
types.processOutcome = objectOf 'ProcessOutcome',
  last_seq: types.seqNumber

# AkGame: {
#   date: Float
#   id: String
#   players: Array<AkPlayerScore>
# }
# see alkindi.Game
# 
# AkPlayerScore: = {
#   username: String,
#   score: Int
# }
# see alkindi.PlayerScore

module.exports = types
