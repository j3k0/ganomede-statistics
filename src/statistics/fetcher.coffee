clients = require '../clients'
log = require '../log'
extend = require('../toolbox').extend
monadsChain = require('../toolbox').monadsChain
taskFromNode = require('../toolbox').taskFromNode
Task = require 'data.task'
Async = require('control.async')(Task)
CoordinatorClient = require './coordinator-client'
alkindi = require 'alkindi'

nop = () ->

#
# FetcherConfig: ClientConfig (see ../clients.coffee)
#
# FetcherState: {
#   secret: String
#   since: Int
# }
#

class Fetcher

  # FetcherConfig -> Fetcher
  constructor: (@config, @storage) ->
    clientFactory = clients(@config, CoordinatorClient.create)
    @client = clientFactory "coordinator/v1"
    @secret = process.env.API_SECRET

  # Run the fetcher endlessly
  #
  # _ -> _
  runStep: (callback) ->
    fetcherStep(@client, @storage, @secret).fork(
      (err)  =>
        log.error "Fetcher Error", @config
        if err.message != "lock can't be acquired"
          log.error err.stack
        callback err
      (data) ->
        callback data
    )

# FetcherConfig -> Fetcher
Fetcher.create = (config, storage) -> new Fetcher(config, storage)

# CoordinatorClient -> Storage -> Secret -> Task(FetcherState)
fetcherStep = Fetcher._step = (client, storage, secret) ->
  lockWorker(storage)
  .chain loadLastSeq(storage)
  .chain loadGames(client, secret)
  .chain processGamesBody(storage)
  .chain saveLastSeq(storage)
  .chain unlockWorker(storage)

# CoordinatorClient -> Secret -> Since -> Task<GamesBody>
loadGames = (client, secret) -> (lastSeq) ->
  client.gameover secret, lastSeq

# Storage -> _ -> Task<Since>
loadLastSeq = (storage) -> () -> new Task (reject, resolve) ->
  storage.getLastSeq taskFromNode(reject, resolve)

# Storage -> Since -> Task<_>
saveLastSeq = (storage) -> (lastSeq) -> new Task (reject, resolve) ->
  storage.saveLastSeq lastSeq, taskFromNode(reject, resolve)

# Storage -> Task<_>
lockWorker = (storage) -> storage.lockTask "worker"

# Storage -> _ -> Task<_>
unlockWorker = (storage) -> () -> new Task (reject, resolve) ->
  storage.unlock "worker", taskFromNode(reject, resolve)

# Storage -> FetcherState -> GamesBody -> Task<Since>
processGamesBody = Fetcher._processGamesBody =
(storage, state) -> (body) ->
  processGames(storage)(body?.results || [])
  .map () -> body.last_seq

# Game -> Task(_)
processGame = Fetcher._processGame = (storage) -> (game) ->
  loadArchives(storage, game)
  .map   addGame
  .chain saveOutcomes(storage)

# Storage -> Array<Game> -> Task(_)
processGames = (storage) -> monadsChain Task.of, processGame(storage)

# Storage -> Game -> Task(GameWithArchives)
loadArchives = (storage, game) ->
  loadPlayersArchives storage, game.type, usernames(game)
  .map gameWithArchive(game)

# Game -> Array<Username>
usernames = (game) ->
  players(game).map (p) -> p.name

# Game -> Array<PlayerScore>
players = (game) ->
  game?.gameOverData?.players || []

# Game -> Array<PlayerArchive> -> GameWithArchives
gameWithArchive = (game) -> (archives) ->
  game: game
  archives: archives

# Storage -> Type -> Array<Username> -> Task(Array<PlayerArchive>)
loadPlayersArchives = (storage, type, players) ->
  tasks = players.map loadPlayerArchive(storage, type)
  Async.parallel tasks

# Storage -> Type -> Username -> Task<PlayerArchive>
loadPlayerArchive = (storage, type) ->
  (username) -> new Task (reject, resolve) ->
    storage.getArchives type, username, (err, games) ->
      if err
      then reject err
      else resolve
        username: username
        games: games

# Storage -> PlayerGameOutcome -> Task<_>
saveOutcome = (storage) -> (outcome) ->
  saveLevel(storage) outcome
  .chain getRank(storage)
  .chain archiveGame(storage)

# Storage -> PlayerGameRank -> Task<_>
archiveGame = (storage) -> (pgr) -> new Task (reject, resolve) ->
  if pgr.username == "TheChicken"
    log.info "archived",
      date:     pgr.game.game.date
      username: pgr.username
      outcome:  pgr.game.outcome
  storage.archiveGame(
    pgr.type
    pgr.username
    pgr.game
    taskFromNode(reject, resolve)
  )

# Storage -> PlayerGameOutcome -> Task<PlayerGameOutcome>
saveLevel = (storage) -> (pgo) -> new Task (reject, resolve) ->
  storage.saveLevel(
    pgo.type
    pgo.username
    pgo.game.outcome.newLevel
    taskFromNode(
      reject
      () -> resolve pgo
    )
  )

# Storage -> PlayerGameOutcome -> Task<PlayerGameRank>
getRank = (storage) -> (pgo) -> new Task (reject, resolve) ->
  storage.getRank pgo.type, pgo.username, taskFromNode(
    reject
    (rank) -> resolve
      username: pgo.username,
      type: pgo.type,
      game: extend pgo.game,
        outcome:
          newLevel: pgo.game.outcome.newLevel
          newRank:  rank
  )

# Storage -> Array<PlayerGameOutcome> -> Task(_)
saveOutcomes = Fetcher._saveOutcomes = (storage) ->
  monadsChain Task.of, saveOutcome(storage)

# Game -> AkGame
akGame = (game) ->
  id: game.id
  date: 0.001 * new Date()
  players: players(game).map akPlayerScore

# PlayerScore -> AkPlayerScore
akPlayerScore = (player) ->
  username: player.name
  score: player.score

noDecay = (t0,t1,level) ->
  newLevel: level

# GameWithArchives -> Array<PlayerGameOutcome>
addGame = Fetcher._addGame = (gameWA) ->
  alkindi.addGame(
    alkindi.simpleLevelUpdate,
    noDecay,
    gameWA.archives, akGame(gameWA.game)
  ).map (outcome) -> extend outcome, type:gameWA.game.type

module.exports = Fetcher
