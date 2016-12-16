#
# Library of utility methods
#

Task = require 'data.task'
module.exports = exports = {}

clone = exports.clone = (obj) -> JSON.parse(JSON.stringify(obj))

extend = exports.extend = (object, properties) ->
  ret = {}
  for key, val of object
    ret[key] = val
  for key, val of properties
    ret[key] = val
  ret

# (() -> M<_>) -> (T -> M<_>) -> Array<T> -> M<_>
#
# `chain` monads generated by calling f (T -> M<_>) on each element
monadsChain = exports.monadsChain = (init, f) -> (array) ->
  m = init()
  array.forEach (value, index) ->
    m = m.chain f.bind(null, value)
    if index % 64 == 63
      m = m.chain deferred
  m

# callstack cleaner
deferred = exports.deferred = (x) ->
  new Task (reject, resolve) ->
    setImmediate ->
      resolve x

# mondadChain an array, return the array itself
# boxed into the monad (ignoring what was done to
# the data)
# Usefull for stuff that don't affect the data,
# like storing in a database...
# (() -> M<_>) -> (T -> M<_>) -> Array<T> -> M<Array<T>>
silentChain = exports.silentChain = (init, f) -> (array) ->
  monadsChain(init, f)(array).map () -> array

taskFromNode = exports.taskFromNode =
(reject, resolve) -> (err, value) ->
  if err then reject err else resolve value

safeParseJSON = exports.safeParseJSON = (reply) ->
  try
    return JSON.parse(reply)
  catch err
    return null

ensure = exports.ensure = (calls) ->
  ensure.error = null
  calls.forEach (call) ->
    try
      call()
    catch err
      ensure.error = err
  !ensure.error

