Task = require 'data.task'
Async = require('control.async') Task
alkindi = require 'alkindi'
{ AVLTree } = require('binary-search-tree-continued')

log = require '../log'
clients = require '../clients'
{
  game: isGame
  username: isUsername
  gameWithArchives: isGameWithArchive
  seqNumber: isSeqNumber
  gamesBody: isGamesBody
  gameType: isGameType
  gameOutcome: isGameOutcome
  playerArchive: isPlayerArchive
  playerGameOutcome: isPlayerGameOutcome
  playerGameRank: isPlayerGameRank
  arrayOf: isArrayOf
} = require './types'

CoordinatorClient = require './coordinator-client'
{
  extend, monadsChain, silentChain, taskFromNode, ensure,
  deferred, plausibleDate
} = require '../toolbox'

nop = () ->

# Compute the order between 2 games
gamesOrder = (a, b) ->
  if a.date < b.date
    return -1
  if a.date > b.date
    return 1
  # When dates are identical, compare based on player names
  pa = a.gameOverData.players[0].username
  pb = b.gameOverData.players[0].username
  if pa < pb
    return -1
  if pa > pb
    return 1
  return 0

# Array [Game] sorted by date
waitingList = new AVLTree({ compareKeys: gamesOrder})

waitingListAdd = (game) ->
  waitingList.insert game, true
  Task.of game

waitingListPop = () ->
  first = waitingList.getMinKey()
  if first
    waitingList.delete first
  Task.of first

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
        if err.message != "lock can't be acquired"
          log.error {stack:err.stack, message:err.message, config:@config},
            "fetcher error"
        else
          log.error {config:@config}, "lock can't be acquired"
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
  .chain loadGames(storage, client, secret)
  .chain saveLastSeq(storage)
  .chain -> processWaitingList(storage)
  .chain unlockWorker(storage)

# fakeDate :: Id -> Timestamp
# A deterministic pseudo-random date in January 2016
# based on the game ID.
fakeDate = (id) ->
  epoch = 1451606400 # 2016-01-01
  month = 2592000 # seconds in a month
  epoch + (parseInt(id.replace(/[0abcdef]/g,'')) % month)

# processLoadedResults :: [LoadedResults] -> GamesBody.results
processLoadedResults = (results) ->
  results
  .map (game, index) ->
    god = game.gameOverData || {}
    players = god.players || god.state?.players || []
    id: game.id
    date: plausibleDate(game.date || fakeDate(game.id))
    type: game.type
    gameOverData:
      players: players.map (playerScore) ->
        username: playerScore.name
        score: playerScore.score
  .sort (a, b) -> a.date - b.date

# loadGames ::
#   Storage -> CoordinatorClient -> Secret -> SeqNumber -> Task<SeqNumber>
loadGames = Fetcher._loadGames = (storage, client, secret) -> (lastSeq) ->
  client.gameover secret, lastSeq
  .map (body) ->
    last_seq: body.last_seq
    results: processLoadedResults(body.results)
  .chain (gamesBody) ->
    log.info {
      last_seq: gamesBody.last_seq
      from_seq: lastSeq
      limit: client.limit
    }, "loadGames"
    addGamesToWaitingList(storage)(gamesBody.results)
    .chain deferred
    .chain ->
      if gamesBody.last_seq - lastSeq < client.limit
        log.info "we're done"
        Task.of gamesBody.last_seq # we're done
      else
        log.info "loading more games..."
        loadGames(storage, client, secret)(gamesBody.last_seq)

# loadLastSeq :: Storage -> _ -> Task<SeqNumber>
loadLastSeq = (storage) -> () -> new Task (reject, resolve) ->
  storage.getLastSeq taskFromNode(reject, resolve)

# saveLastSeq :: Storage -> SeqNumber -> Task<_>
saveLastSeq = (storage) -> (lastSeq) -> new Task (reject, resolve) ->
  if ensure [ -> isSeqNumber lastSeq ]
  then storage.saveLastSeq lastSeq, taskFromNode(reject, resolve)
  else reject ensure.error

# lockWorker :: Storage -> Task<_>
lockWorker = (storage) -> storage.lockTask "worker"

# unlockworker :: Storage -> _ -> Task<_>
unlockWorker = (storage) -> () -> new Task (reject, resolve) ->
  storage.unlock "worker", taskFromNode(reject, resolve)

# processGamesBody :: Storage -> GamesBody -> Task<SeqNumber>
# processGamesBody = Fetcher._processGamesBody =
#   (storage) -> (body) ->
#     if ensure [ -> isGamesBody body ]
#       processGames(storage)(body?.results || [])
#       .chain () -> processWaitingList(storage)
#       .map () -> body?.last_seq
#     else
#       Task.rejected ensure.error

# processWaitingList :: Storage -> Task<_>
processWaitingList = (storage) ->
  waitingListPop()
  .chain (game) ->
    if !game
      Task.of null
    else
      processGame(storage)(game)
      .chain deferred
      .chain -> processWaitingList(storage)

# addGameToWaitingList :: Storage -> Game -> Task(Game)
addGameToWaitingList = (storage) -> (game) ->
  if ensure [ -> isGame game ]
  then waitingListAdd game
  else Task.rejected ensure.error

# addGamesToWaitingList :: Storage -> [Game] -> Task([Game])
addGamesToWaitingList = (storage) ->
  silentChain Task.of, addGameToWaitingList(storage)

# processGame :: Storage -> Game -> Task(_)
processGame = Fetcher._processGame = (storage) -> (game) ->
  if ensure [ -> isGame game ]
    loadArchives(storage, game)
    .chain incrGameIndex(storage)
    .map   addGame
    .chain saveOutcomes(storage)
  else
    Task.rejected ensure.error

# loadArchives :: Storage -> Game -> Task(GameWithArchives)
loadArchives = (storage, game) ->
  if ensure [ -> isGame game ]
    loadPlayersArchives storage, game.type, usernames(game)
    .map gameWithArchives game
  else
    Task.rejected ensure.error

# incrGameIndex :: Storage -> GameWithArchives -> GameWithArchives
incrGameIndex = (storage) -> (gameWA) -> new Task (reject, resolve) ->
  if ensure [ -> isGameWithArchive gameWA ]
  then storage.incrGameIndex taskFromNode(
    reject
    (value) -> resolve addIndex(+value, gameWA)
  )
  else Task.rejected ensure.error

# usernames :: Game -> [Username]
usernames = (game) ->
  if ensure [ -> isGame game ]
  then players(game).map (p) -> p.username

# players :: Game -> [PlayerScore]
players = (game) ->
  if ensure [ -> isGame game ]
  then game.gameOverData.players || []

# gameWithArchives :: Game -> [PlayerArchive] -> GameWithArchives
gameWithArchives = (game) -> (archives) ->
  if ensure [
    -> isGame game
    -> isArrayOf('[PlayerArchive]', isPlayerArchive) archives
  ]
    index: 0
    game: game
    archives: archives

# addIndex :: Index -> GameWithArchives -> GameWithArchives
addIndex = (index, gameWA) ->
  extend gameWA, index:index

# loadPlayersArchives ::
#   Storage -> GameType -> [Username] -> Task([PlayerArchive])
loadPlayersArchives = (storage, type, players) ->
  if ensure [
    -> isGameType type
    -> isArrayOf('[Username]', isUsername) players
  ]
    tasks = players.map loadPlayerArchive(storage, type)
    Async.parallel tasks
  else
    Task.rejected ensure.error

# loadPlayerArchive :: Storage -> GameType -> Username -> Task<PlayerArchive>
loadPlayerArchive = (storage, type) -> (username) ->
  if ensure [
    -> isGameType type
    -> isUsername username
  ]
    new Task (reject, resolve) ->
      storage.getArchives type, username, (err, games) ->
        if err
        then reject err
        else resolve
          username: username
          games: games
  else
    Task.rejected ensure.error

# saveOutcome :: Storage -> PlayerGameOutcome -> Task<_>
saveOutcome = (storage) -> (outcome) ->
  if ensure [ -> isPlayerGameOutcome outcome ]
    saveLevel(storage) outcome
    .chain getRank(storage)
    .chain archiveGame(storage)
  else
    Task.rejected ensure.error

# archiveGame :: Storage -> PlayerGameRank -> Task<_>
archiveGame = (storage) -> (pgr) -> new Task (reject, resolve) ->
  if ensure [ -> isPlayerGameRank pgr ]
    log.info {
      date:     pgr.game.game.date
      username: pgr.username
      newLevel: pgr.game.outcome.newLevel
      newRank:  pgr.game.outcome.newRank
    }, "archived"
    storage.archiveGame(
      pgr.type
      pgr.username
      pgr.game
      taskFromNode(reject, resolve)
    )
  else
    Task.rejected ensure.error

# saveLevel :: Storage -> PlayerGameOutcome -> Task<PlayerGameOutcome>
saveLevel = (storage) -> (pgo) -> new Task (reject, resolve) ->
  if ensure [ -> isPlayerGameOutcome pgo ]
  then storage.saveLevel(
    pgo.type
    pgo.username
    pgo.game.outcome.newLevel
    taskFromNode(
      reject
      () -> resolve pgo
    )
  )
  else Task.rejected ensure.error

# getRank :: Storage -> PlayerGameOutcome -> Task<PlayerGameRank>
getRank = (storage) -> (pgo) -> new Task (reject, resolve) ->
  if ensure [ -> isPlayerGameOutcome pgo ]
  then storage.getRank pgo.type, pgo.username, taskFromNode(
    reject
    (rank) -> resolve
      username: pgo.username,
      type: pgo.type,
      game: extend pgo.game,
        outcome:
          newLevel: pgo.game.outcome.newLevel
          newRank:  1 + rank
  )
  else Task.rejected ensure.error

# saveOutcome :: Storage -> [PlayerGameOutcome] -> Task([PlayerGameOutcome])
saveOutcomes = Fetcher._saveOutcomes = (storage) ->
  silentChain Task.of, saveOutcome(storage)

# 15/08/2015 00:00 GMT
defaultDate = (gameWA) ->
  alkindi.TRIPOCH + gameWA.index

# akGame :: GameWithArchives -> AkGame
akGame = (gameWA) ->
  id: gameWA.game.id
  date: (gameWA.game.date || defaultDate(gameWA))
  players: players(gameWA.game)

noDecay = (t0,t1,level) ->
  newLevel: level

# fromAkOutcome :: AkPlayerGameOutcome -> PlayerGameOutcome
fromAkOutcome = (type) -> (ak) ->
  username: ak.username
  type: type
  game:
    outcome: ak.game.outcome
    game:
      id: ak.game.game.id
      date: ak.game.game.date
      players: ak.game.game.players

# addGame :: GameWithArchives -> [PlayerGameOutcome]
addGame = Fetcher._addGame = (gameWA) ->
  # log.info {gameWA}, 'addGame'
  alkindi.addGame(
    alkindi.simpleLevelUpdate,
    noDecay,
    gameWA.archives, akGame(gameWA)
  )
  .map (ak) ->
    # log.info {ak}, 'addGame.outcome'
    ak
  .map fromAkOutcome(gameWA.game.type)

module.exports = Fetcher
# vim: ts=2:sw=2:et:
