#
# Talks to rules server
#

restify = require 'restify'
log = require '../log'

class CoordinatorClient

  constructor: (jsonClient) ->
    if !jsonClient
      throw new Error('jsonClient required')
    @client = jsonClient

  gameover: (secret, since) -> new Task (reject, resolve) ->
    path = gameoverPath @client, secret, since
    @client.get path, gameoverHandler(reject, resolve)

CoordinatorClient.create = (jsonClient) -> new CoordinatorClient(jsonClient)

# JsonClient -> Subpath -> Path
endpoint = CoordinatorClient._endpoint = (jsonClient, subpath) ->
  "#{jsonClient.url?.pathname || ''}#{subpath}"

# JsonClient -> Secret -> Since -> Path
gameoverPath = CoordinatorClient._gameoverPath =
(jsonClient, secret, since) ->
  params = "secret=#{secret}&since=#{since}"
  endpoint jsonClient, "/gameover?#{params}"

# (Error -> _) -> (GamesBody -> _) -> Error -> Request -> Response -> GamesBody
gameoverHandler = CoordinatorClient._gameoverHandler =
(reject, resolve) -> (err, req, res, body) ->
  if err
    log.error "/gameover failed", err
    reject err
  else if res.statusCode != 200
    log.error "GET /gameover code", code:res.statusCode
    reject new Error "HTTP#{res.statusCode}"
  else
    resolve body

module.exports = CoordinatorClient
# vim: ts=2:sw=2:et:
