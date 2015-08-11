#
# Library of utility methods
#

module.exports = exports = {}

clone = exports.clone = (obj) -> JSON.parse(JSON.stringify(obj))

extend = exports.extend = (object, properties) ->
  ret = {}
  for key, val of object
    ret[key] = val
  for key, val of properties
    ret[key] = val
  ret

