# Prevent creating new objects on each move
restify = require 'restify'
urllib = require 'url'

_clients = {}

# ClientConfig: {
#   host: String
#   port: String
# }

# ClientConfig -> (JsonClient -> Client) -> Type -> Client
clients = (config, factory) -> (type) ->
  _clients[type] || _clients[type] = factory restify.createJsonClient
    url: urllib.format
      protocol: 'http'
      hostname: config.host
      port:     config.port
      pathname: type

module.exports = clients

# vim: ts=2:sw=2:et:
