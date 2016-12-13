Task = require 'data.task'
Async = require('control.async') Task
alkindi = require 'alkindi'

log = require '../log'
clients = require '../clients'
types = require './types'
CoordinatorClient = require './coordinator-client'
{
  extend, monadsChain, silentChain, taskFromNode
} = require '../toolbox'

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

# fakeDate :: Id -> Timestamp
# A deterministic pseudo-random date in January 2016
# based on the game ID.
fakeDate = (id) ->
  epoch = 1451606400000 # 2016-01-01
  month = 2592000000 # millis in a month
  epoch + (parseInt(id.replace(/[0abcdef]/g,'')) % month)

# loadGames :: CoordinatorClient -> Secret -> SeqNumber -> Task<GamesBody>
loadGames = Fetcher._loadGames = (client, secret) -> (lastSeq) ->
  client.gameover secret, lastSeq
  .map (body) ->
    last_seq: body.last_seq
    results: body.results.map (game, index) ->
      id: game.id
      date: game.date || fakeDate(game.id)
      type: game.type
      gameOverData:
        players: game.gameOverData.players.map (playerScore) ->
          username: playerScore.name
          score: playerScore.score

# loadLastSeq :: Storage -> _ -> Task<SeqNumber>
loadLastSeq = (storage) -> () -> new Task (reject, resolve) ->
  storage.getLastSeq taskFromNode(reject, resolve)

# saveLastSeq :: Storage -> SeqNumber -> Task<_>
saveLastSeq = (storage) -> (lastSeq) -> new Task (reject, resolve) ->
  types.seqNumber lastSeq
  storage.saveLastSeq lastSeq, taskFromNode(reject, resolve)

# lockWorker :: Storage -> Task<_>
lockWorker = (storage) -> storage.lockTask "worker"

# unlockworker :: Storage -> _ -> Task<_>
unlockWorker = (storage) -> () -> new Task (reject, resolve) ->
  storage.unlock "worker", taskFromNode(reject, resolve)

# processGamesBody :: Storage -> GamesBody -> Task<SeqNumber>
processGamesBody = Fetcher._processGamesBody =
  (storage) -> (body) ->
    types.gamesBody body
    processGames(storage)(body?.results || [])
    .map () -> body?.last_seq

# outcomeToGame :: GameType -> GameOutcome -> Game
outcomeToGame = (type) -> (outcome) ->
  types.gameType type
  types.gameOutcome outcome
  types.game
    id: outcome.id
    date: outcome.date
    type: type,
    gameOverData:
      players: outcome.players

concat = (a, b) -> a.concat(b)

# futureOutcomes :: GameWithArchives -> [GameOutcome]
outcomes = (gameWA) ->
  types.gameWithArchives gameWA
  gameWA.archives
  .map((playerArchive) -> playerArchive.games)
  .reduce(concat, [])

# futureOutcomes :: GameWithArchives -> [GameOutcome]
futureOutcomes = (gameWA) ->
  types.gameWithArchives gameWA
  outcomes(gameWA)
  .filter (outcome) -> outcome.game.date > gameWA.game.date

# keepPastGames :: GameWithArchives -> GameWithArchives
# keepPastGames = (gameWA) ->
#   TODO

# addGameToWaitingList :: Storage -> Game -> Task(_)
addGameToWaitingList = (storage) -> (game) ->
  types.game game
  new Task (reject, resolve) ->
    storage.addGameToWaitingList game, taskFromNode(reject, resolve)

# addGamesToWaitingList :: Storage -> [Game] -> Task([Game])
addGamesToWaitingList = (storage) ->
  silentChain Task.of, addGameToWaitingList(storage)

removeGameFromArchives = (storage) -> (game) ->
  types.game game
  game.gameOverData.players

# cleanup archive of all concerned players
# removeFromArchives :: Storage -> [Game] -> Task([Game])
removeGamesFromArchives = (storage) ->
  silentChain Task.of, removeGameFromArchives(storage)

# extractFutureGames :: Storage -> GameWithArchives -> Task(_)
extractFutureGames = (storage) -> (gameWA) ->
  types.gameWithArchives gameWA
  futureOutcomes(gameWA)
  .map outcomeToGame(gameWA.game.type)
  .map addGamesToWaitingList(storage)
  .chain removeGamesFromArchives(storage)

# setAsideFutureGames :: Storage -> GameWithArchives -> Task(GameWithArchives)
setAsideFutureGames = (storage) -> (gameWA) ->
  types.gameWithArchives gameWA
  extractFutureGames(storage, gameWA)
  .map (_) -> keepPastGames(gameWA)

# processGame :: Storage -> Game -> Task(_)
processGame = Fetcher._processGame = (storage) -> (game) ->
  types.game game
  loadArchives(storage, game)
  # .setAsideFutureGames(storage)
  .chain incrGameIndex(storage)
  .map   addGame
  .chain saveOutcomes(storage)

# processGames :: Storage -> [Game] -> Task([Game])
processGames = (storage) -> silentChain Task.of, processGame(storage)

# loadArchives :: Storage -> Game -> Task(GameWithArchives)
loadArchives = (storage, game) ->
  types.game game
  loadPlayersArchives storage, game.type, usernames(game)
  .map gameWithArchives game

# incrGameIndex :: Storage -> GameWithArchives -> GameWithArchives
incrGameIndex = (storage) -> (gameWA) -> new Task (reject, resolve) ->
  types.gameWithArchives gameWA
  storage.incrGameIndex taskFromNode(
    reject
    (value) -> resolve addIndex(+value, gameWA)
  )

# usernames :: Game -> [Username]
usernames = (game) ->
  types.game game
  players(game).map (p) -> p.username

# players :: Game -> [PlayerScore]
players = (game) ->
  types.game game
  game?.gameOverData?.players || []

# gameWithArchives :: Game -> [PlayerArchive] -> GameWithArchives
gameWithArchives = (game) -> (archives) ->
  types.game game
  types.arrayOf('[PlayerArchive]', types.playerArchive) archives
  {
    index: 0
    game: game
    archives: archives
  }

# addIndex :: Index -> GameWithArchives -> GameWithArchives
addIndex = (index, gameWA) ->
  types.gameWithArchives gameWA
  extend gameWA, index:index

# loadPlayersArchives :: Storage -> GameType -> [Username] -> Task([PlayerArchive])
loadPlayersArchives = (storage, type, players) ->
  types.gameType type
  types.arrayOf('[Username]', types.username) players
  tasks = players.map loadPlayerArchive(storage, type)
  Async.parallel tasks

# loadPlayerArchive :: Storage -> GameType -> Username -> Task<PlayerArchive>
loadPlayerArchive = (storage, type) -> (username) ->
  new Task (reject, resolve) ->
    types.gameType type
    types.username username
    storage.getArchives type, username, (err, games) ->
      if err
      then reject err
      else resolve
        username: username
        games: games

# saveOutcome :: Storage -> PlayerGameOutcome -> Task<_>
saveOutcome = (storage) -> (outcome) ->
  types.playerGameOutcome outcome
  saveLevel(storage) outcome
  .chain getRank(storage)
  .chain archiveGame(storage)

# archiveGame :: Storage -> PlayerGameRank -> Task<_>
archiveGame = (storage) -> (pgr) -> new Task (reject, resolve) ->
  types.playerGameRank pgr
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
  types.playerGameOutcome pgo
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
  types.playerGameOutcome pgo
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

# saveOutcome :: Storage -> [PlayerGameOutcome] -> Task([PlayerGameOutcome])
saveOutcomes = Fetcher._saveOutcomes = (storage) ->
  silentChain Task.of, saveOutcome(storage)

# 15/08/2015 00:00 GMT
defaultDate = (gameWA) ->
  1000 * (alkindi.TRIPOCH + gameWA.index)

# akGame :: GameWithArchives -> AkGame
akGame = (gameWA) ->
  id: gameWA.game.id
  date: 0.001 * (gameWA.game.date || defaultDate(gameWA))
  players: players(gameWA.game)

noDecay = (t0,t1,level) ->
  newLevel: level

# fromAkOutcome :: AkPlayerGameOutcome -> PlayerGameOutcome
fromAkOutcome = (type) -> (akOutcome) ->
  types.playerGameOutcome
    username: akOutcome.username
    type: type
    game: akOutcome.game

# addGame :: GameWithArchives -> [PlayerGameOutcome]
addGame = Fetcher._addGame = (gameWA) ->
  alkindi.addGame(
    alkindi.relativeLevelUpdate,
    noDecay,
    gameWA.archives, akGame(gameWA)
  ).map fromAkOutcome(gameWA.game.type)

module.exports = Fetcher
# vim: ts=2:sw=2:et:
