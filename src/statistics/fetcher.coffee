Task = require 'data.task'
Async = require('control.async') Task
alkindi = require 'alkindi'

log = require '../log'
clients = require '../clients'
CoordinatorClient = require './coordinator-client'
{ extend, monadsChain, taskFromNode } = require '../toolbox'

nop = () ->

#
# FetcherConfig: ClientConfig (see ../clients.coffee)
#

class Fetcher

  # Fetcher.constructor :: FetcherConfig -> Fetcher
  constructor: (@config, @storage) ->
    clientFactory = clients(@config, CoordinatorClient.create)
    @client = clientFactory "coordinator/v1"
    @secret = process.env.API_SECRET

  # Run the fetcher once
  #
  # fetcher.runStep :: _ -> _
  runStep: (callback) ->
    fetcherStep(@client, @storage, @secret).fork(
      (err) =>
        log.error "Fetcher Error", @config
        if err.message != "lock can't be acquired"
          log.error err.stack
        callback err
      (data) ->
        callback data
    )

# Fetcher.create :: FetcherConfig -> Fetcher
Fetcher.create = (config, storage) -> new Fetcher(config, storage)

# fetcherStep :: CoordinatorClient -> Storage -> Secret -> Task(_)
fetcherStep = Fetcher._step = (client, storage, secret) ->
  lockWorker(storage)
  .chain loadLastSeq(storage)
  .chain loadGames(client, secret)
  .chain processGamesBody(storage)
  .chain saveLastSeq(storage)
  .chain unlockWorker(storage)

# loadGames :: CoordinatorClient -> Secret -> SeqNumber -> Task<GamesBody>
loadGames = (client, secret) -> (lastSeq) ->
  client.gameover secret, lastSeq

# loadLastSeq :: Storage -> _ -> Task<SeqNumber>
loadLastSeq = (storage) -> () -> new Task (reject, resolve) ->
  storage.getLastSeq taskFromNode(reject, resolve)

# saveLastSeq :: Storage -> SeqNumber -> Task<_>
saveLastSeq = (storage) -> (lastSeq) -> new Task (reject, resolve) ->
  storage.saveLastSeq lastSeq, taskFromNode(reject, resolve)

# lockWorker :: Storage -> Task<_>
lockWorker = (storage) -> storage.lockTask "worker"

# unlockworker :: Storage -> _ -> Task<_>
unlockWorker = (storage) -> () -> new Task (reject, resolve) ->
  storage.unlock "worker", taskFromNode(reject, resolve)

# processGamesBody :: Storage -> GamesBody -> Task<SeqNumber>
processGamesBody = Fetcher._processGamesBody =
(storage) -> (body) ->
  processGames(storage)(body?.results || [])
  .map () -> body.last_seq

# processGame :: Game -> Task(_)
processGame = Fetcher._processGame = (storage) -> (game) ->
  loadArchives(storage, game)
  .chain incrGameIndex(storage)
  .map   addGame
  .chain saveOutcomes(storage)

# processGames :: Storage -> [Game] -> Task(_)
processGames = (storage) -> monadsChain Task.of, processGame(storage)

# loadArchives :: Storage -> Game -> Task(GameWithArchives)
loadArchives = (storage, game) ->
  loadPlayersArchives storage, game.type, usernames(game)
  .map gameWithArchive game

# incrGameIndex :: Storage -> GameWithArchives -> GameWithArchives
incrGameIndex = (storage) -> (gameWA) -> new Task (reject, resolve) ->
  storage.incrGameIndex taskFromNode(
    reject
    (value) -> resolve addIndex(+value, gameWA)
  )

# usernames :: Game -> [Username]
usernames = (game) ->
  players(game).map (p) -> p.name

# players :: Game -> [PlayerScore]
players = (game) ->
  game?.gameOverData?.players || []

# gameWithArchive :: Game -> [PlayerArchive] -> GameWithArchives
gameWithArchive = (game) -> (archives) ->
  index: 0
  game: game
  archives: archives

# addIndex :: Index -> GameWithArchives -> GameWithArchives
addIndex = (index, gameWA) ->
  extend gameWA, index:index

# loadPlayersArchives :: Storage -> Type -> [Username] -> Task([PlayerArchive])
loadPlayersArchives = (storage, type, players) ->
  tasks = players.map loadPlayerArchive(storage, type)
  Async.parallel tasks

# loadPlayerArchive :: Storage -> Type -> Username -> Task<PlayerArchive>
loadPlayerArchive = (storage, type) ->
  (username) -> new Task (reject, resolve) ->
    storage.getArchives type, username, (err, games) ->
      if err
      then reject err
      else resolve
        username: username
        games: games

# saveOutcome :: Storage -> PlayerGameOutcome -> Task<_>
saveOutcome = (storage) -> (outcome) ->
  saveLevel(storage) outcome
  .chain getRank(storage)
  .chain archiveGame(storage)

# archiveGame :: Storage -> PlayerGameRank -> Task<_>
archiveGame = (storage) -> (pgr) -> new Task (reject, resolve) ->
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

# saveLevel :: Storage -> PlayerGameOutcome -> Task<PlayerGameOutcome>
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

# getRank :: Storage -> PlayerGameOutcome -> Task<PlayerGameRank>
getRank = (storage) -> (pgo) -> new Task (reject, resolve) ->
  storage.getRank pgo.type, pgo.username, taskFromNode(
    reject
    (rank) -> resolve
      username: pgo.username,
      type: pgo.type,
      game: extend pgo.game,
        outcome:
          newLevel: pgo.game.outcome.newLevel
          newRank:  1 + rank
  )

# saveOutcome :: Storage -> [PlayerGameOutcome] -> Task(_)
saveOutcomes = Fetcher._saveOutcomes = (storage) ->
  monadsChain Task.of, saveOutcome(storage)

# 15/08/2015 00:00 GMT
defaultDate = (gameWA) ->
  1000 * (alkindi.TRIPOCH + gameWA.index)

# akGame :: GameWithArchives -> AkGame
akGame = (gameWA) ->
  id: gameWA.game.id
  date: 0.001 * (gameWA.game.date || defaultDate(gameWA))
  players: players(gameWA.game).map akPlayerScore

# akPlayerScore :: PlayerScore -> AkPlayerScore
akPlayerScore = (player) ->
  username: player.name
  score: player.score

noDecay = (t0,t1,level) ->
  newLevel: level

# addGame :: GameWithArchives -> [PlayerGameOutcome]
addGame = Fetcher._addGame = (gameWA) ->
  alkindi.addGame(
    alkindi.relativeLevelUpdate,
    noDecay,
    gameWA.archives, akGame(gameWA)
  ).map (outcome) -> extend outcome, type:gameWA.game.type

module.exports = Fetcher
# vim: ts=2:sw=2:et:
