clients = require '../clients'
log = require '../log'
extend = require('../toolbox').extend
monadsChain = require('../toolbox').monadsChain
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
  constructor: (config, @storage) ->
    clientFactory = clients(config, CoordinatorClient.create)
    @client = clientFactory "coordinator/v1"
    @state =
      secret: process.env.API_SECRET
      since:  -1
    log.info "Fetcher initialized", config:config
    
  # Run the fetcher endlessly
  #
  # _ -> _
  run: () ->
    fetcherStep(@client, @storage, @state).fork(
      (err)  =>
        log.error "Fetcher error", err
        process.nextTick @run
      (data) =>
        @state = data
        process.nextTick @run
    )

# FetcherConfig -> Fetcher
Fetcher.create = (config, storage) -> new Fetcher(config, storage)

# CoordinatorClient -> Storage -> FetcherState -> Task(FetcherState)
fetcherStep = Fetcher._step = (client, storage, state) ->
  client.gameover state.secret, state.since
  .chain processGamesBody(storage, state)

# Storage -> FetcherState -> GamesBody -> Task(FetcherState)
processGamesBody = Fetcher._processGamesBody =
(storage, state) -> (body) ->
  processGames(storage)(body?.results || [])
  .map () -> extend state, last_seq: body.last_seq

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

# Storage -> Type -> Username -> Task<GameOutcome>
loadPlayerArchive = (storage, type) ->
  (username) -> new Task (reject, resolve) ->
    storage.getArchives type, username, (err, data) ->
      if err
      then reject err
      else resolve
        username: username
        games: data

# Storage -> PlayerGameOutcome -> Task<_>
saveOutcome = (storage) -> (outcome) -> new Task (reject, resolve) ->
  resolve storage.saveArchive(
    outcome.type
    outcome.username
    outcome.game
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

# GameWithArchives -> Array<PlayerGameOutcome>
addGame = Fetcher._addGame = (gameWA) ->
  alkindi.addGame(
    alkindi.simpleLevelUpdate,
    alkindi.simpleLevelDecay,
    gameWA.archives, akGame(gameWA.game)
  ).map (outcome) -> extend outcome, type:gameWA.game.type

module.exports = Fetcher
