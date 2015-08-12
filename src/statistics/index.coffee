config = require '../../config'
endpoint = require '../endpoint'
utils = require './utils'
Storage = require './storage'
Fetcher = require './fetcher'

# .../stats endpoint
stats = (storage) -> (req, res, next) ->
  endpoint.performIO res, next,
    utils.statsEndpoint(storage, req.params)

# .../archive endpoint
archive = (storage) -> (req, res, next) ->
  endpoint.performEndpointIO res, next,
    utils.archiveEndpoint(storage, req.params)

# Create a Statistics API
createApi = (options={}) ->

  # Initialization
  storage = options.storage ||
    Storage.create(config.redis)

  # Create a games fetcher
  fetcher = options.fetcher ||
    Fetcher.create(config.coordinator, storage)

  # Register routes
  addRoutes: (prefix, server) ->
    base = "/#{prefix}/:gameType/:gameVersion/:username"
    server.get "#{base}/stats",   stats(storage)
    server.get "#{base}/archive", archive(storage)

  # Run the games fetcher
  runFetcher: () ->
    fetcher.run()

module.exports =
  createApi: createApi

# vim: ts=2:sw=2:et:
