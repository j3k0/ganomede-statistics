config = require '../../config'
endpoint = require '../endpoint'
utils = require './utils'
Storage = require './storage'
Fetcher = require './fetcher'
tagizer = require 'ganomede-tagizer'

# .../archive endpoint
archive = (storage) -> (req, res, next) ->
  endpoint.performIO res, next,
    utils.archiveEndpoint(storage, req.params)

# .../rank endpoint
rank = (storage) -> (req, res, next) ->
  endpoint.performIO res, next,
    utils.rankEndpoint(storage, req.params)

# Create a Statistics API
createApi = (options={}) ->

  storage = options.storage ||
    Storage.create(config.redis)

  # Register routes
  addRoutes: (prefix, server) ->
    base = "/#{prefix}/:gameType/:gameVersion/:tag"
    tagParam = tagizer.middleware 'params', 'tag'
    server.get "#{base}/archive", tagParam, archive(storage)
    server.get "#{base}/rank", tagParam, rank(storage)

  # Run the games fetcher
  runFetcherStep: (callback) ->

    fetcher = options.fetcher ||
      Fetcher.create(config.coordinator, storage)

    fetcher.runStep callback

  quit: -> storage.quit()

module.exports =
  createApi: createApi

# vim: ts=2:sw=2:et:
