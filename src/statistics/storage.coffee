log = require '../log'
redis = require 'redis'
Task = require 'data.task'
taskFromNode = require('../toolbox').taskFromNode

PREFIX_SEPARATOR = ':'
LOCK_TIMEOUT_SEC = (10)

class Storage
  constructor: (redis, prefix) ->
    @redis = redis
    @prefix = prefix

  key: (gameType, parts...) ->
    [@prefix, gameType].concat(parts).join(PREFIX_SEPARATOR)

  # Type -> Username -> GetArchiveCallback
  getArchives: (type, username, callback) ->
    @redis.zrange [@key(type, username), 0, -1], (err, reply) ->
      if err
        log.error 'redis.getArchives() failed',
          err: err
          id: id
        callback err
      else
        callback null, JSON.parse(reply)

  # Type -> Username -> GameOutcome -> Void
  saveArchive: (type, username, game) ->
    @redis.zadd [
      @key(type, username),
      Math.round(game.date),
      JSON.stringify(game)
    ]

  lockKey: (lockName) -> @key("lock", lockName)

  lockTask: (lockName) ->
    timeout = LOCK_TIMEOUT_SEC * 1000 + (new Date().getTime())
    lock @redis, @lockKey(lockName), timeout

  lock: (lockName, callback) ->
    lockTask lockName
    .fork(
      (err) -> callback err
      () -> callback null, lockName
    )

  unlock: (lockName, callback) ->
    @redis.del @lockKey(lockName), callback

  getLastSeq: (callback) ->
    @redis.get @key("lastseq"), (err, value) ->
      if err then value = -1
      callback null, value

  saveLastSeq: (value) ->
    @redis.set @key("lastseq"), lastseq

  quit: ->
    @redis.quit()

# StorageConfig -> Storage
Storage.create = exports.createStorage = (config) ->
  new Storage(
    redis.createClient(config.port, config.host)
    config.prefix
  )

# Acquire the lock for the given time (in ms)
#
# Redis -> Key -> Timeout -> Task<_>
lock = (redis, lockkey, timeout) ->
  acquireFreeLock redis, lockkey, timeout
  .map   freeLockStatus
  .chain loadLockedExpiry(redis, lockkey)
  .chain expiryStatus
  .chain rejectLocked
  .chain acquireExpired(redis, lockkey, timeout)
  .chain updateExpiry(redis, lockkey)

# LockStatus
ACQUIRED = "acquired"
LOCKED = "locked"
EXPIRED = "expired"

# Redis -> Key -> Timeout -> Task<RedisStatus>
acquireFreeLock = (redis, lockkey, timeout) -> new Task (reject, resolve) ->
  redis.setnx lockkey, timeout, taskFromNode(reject, resolve)
  
# RedisStatus -> LockStatus
freeLockStatus = (value) ->
  if +value == 1 then ACQUIRED else LOCKED

# Redis -> Key -> LockStatus -> Task<LockStatus|ExpiryDate>
loadLockedExpiry = (redis, lockkey) -> (status) ->
  new Task (reject, resolve) ->
    if status == LOCKED
      redis.get lockkey, taskFromNode(reject, resolve)
    else
      resolve status

# (LockStatus|ExpiryDate) -> Task<LockStatus>
expiryStatus = (value) -> new Task (reject, resolve) ->
  if value == ACQUIRED
    resolve ACQUIRED
  else if (new Date().getTime()) > +value
    resolve EXPIRED
  else
    resolve LOCKED

# LockStatus -> Task<LockStatus>
rejectLocked = (status) -> new Task (reject, resolve) ->
  if status == LOCKED
    reject new Error "lock can't be acquired"
  else
    resolve status

# Redis -> Key -> Timeout -> LockStatus -> Task<_>
acquireExpired = (redis, lockkey, timeout) -> (status) ->
  new Task (reject, resolve) ->
    if status == EXPIRED
      redis.set lockkey, timeout, taskFromNode(reject, resolve)
    else
      resolve status

# Redis -> Key -> _ -> Task<T>
updateExpiry = (redis, lockkey) -> () -> new Task (reject, resolve) ->
  redis.expire lockkey, LOCK_TIMEOUT_SEC, taskFromNode(reject, resolve)

module.exports = Storage

