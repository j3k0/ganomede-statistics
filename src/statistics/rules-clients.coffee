# Prevent creating new objects on each move
restify = require 'restify'
RulesClient = require './rules-client'
config = require '../../config'
urllib = require 'url'

_rulesClients = {}

rulesClients = (type) ->
  ret = _rulesClients[type]
  if ret
    return ret

  return _rulesClients[type] = new RulesClient restify.createJsonClient(
    url: urllib.format
      protocol: 'http'
      hostname: config.rules.host
      port: config.rules.port
      pathname: type
  )

module.exports = rulesClients

# vim: ts=2:sw=2:et:
