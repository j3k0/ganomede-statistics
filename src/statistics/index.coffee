config = require '../../config'
u = require('./utils')

# .../stats endpoint
stats = (storage) -> (req, res, next) ->
  u.performIO res, next,
    u.getParams(req, res, next)
    .chain u.checkParams
    .chain u.loadArchive(storage)
    .map   u.getStats
    .map   (data) -> data.stats

# .../archive endpoint
archive = (storage) -> (req, res, next) ->
  u.performIO res, next,
    u.getParams(req, res, next)
    .chain u.checkParams
    .chain u.loadArchive(storage)
    .map   (data) -> data.archive

createApi = (options={}) ->

  # Initialization
  storage = options.storage || u.createStorage(config)

  # Routes
  addRoutes: (prefix, server) ->
    endpoint = "/#{prefix}/:gameType/:gameVersion/:username"
    server.get "#{endpoint}/stats",   stats(storage)
    server.get "#{endpoint}/archive", archive(storage)

module.exports =
  createApi: createApi

# vim: ts=2:sw=2:et:
