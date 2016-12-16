#
# Talks to rules server
#

restify = require 'restify'
log = require '../log'
Task = require 'data.task'

class CoordinatorClient

  constructor: (jsonClient) ->
    if !jsonClient
      throw new Error('jsonClient required')
    @client = jsonClient
    @limit = 16384

  # String -> String -> Task<GamesBody>
  gameover: (secret, since) -> new Task (reject, resolve) =>
    path = gameoverPath @client, secret, since, @limit
    log.info get:path
    @client.get path, gameoverHandler(reject, resolve)

CoordinatorClient.create = (jsonClient) -> new CoordinatorClient(jsonClient)

# JsonClient -> Subpath -> Path
endpoint = CoordinatorClient._endpoint = (jsonClient, subpath) ->
  "#{jsonClient?.url?.pathname || ''}#{subpath}"

# JsonClient -> Secret -> Since -> Path
gameoverPath = CoordinatorClient._gameoverPath =
(jsonClient, secret, since, limit = -1) ->
  params = "secret=#{secret}"
  if since != null && since != -1
    params = "#{params}&since=#{since}"
  if limit != null && limit != -1
    params = "#{params}&limit=#{limit}"
  endpoint jsonClient, "/gameover?#{params}"

# (Error -> _) -> (GamesBody -> _) -> Error -> Request -> Response -> GamesBody
gameoverHandler = CoordinatorClient._gameoverHandler =
(reject, resolve) -> (err, req, res, body) ->
  if err
    reject err
  else if res.statusCode != 200
    reject new Error "HTTP#{res.statusCode}"
  else
    resolve body

module.exports = CoordinatorClient
# vim: ts=2:sw=2:et:
