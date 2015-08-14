#
# Generic endpoint utils
#

log = require './log'
module.exports = exports = {}

# Send and log a failed request
sendError = exports.sendError = (send, next) -> (err) ->
  log.error err
  send err
  next()

# Send and log a successful request
sendSuccess = exports.sendSuccess = (send, next) -> (data) ->
  # log.info data
  send data
  next()

# Perform the IO, send the response using res, call next.
performIO = exports.performIO = (res, next, io) ->
  io.fork(
    sendError(res.send.bind(res), next),
    sendSuccess(res.send.bind(res), next)
  )
