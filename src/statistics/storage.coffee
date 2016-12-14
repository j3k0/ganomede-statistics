log = require '../log'
redis = require 'redis'
Task = require 'data.task'
taskFromNode = require('../toolbox').taskFromNode
safeParse = require('../toolbox').safeParseJSON

PREFIX_SEPARATOR = ':'
LOCK_TIMEOUT_SEC = (10)
LEADERBOARD_KEY = '#'

roundedDate = (date) -> Math.round(date)

class Storage
  constructor: (redis, prefix) ->
    @redis = redis
    @prefix = prefix

  key: (parts...) ->
    [@prefix].concat(parts).join(PREFIX_SEPARATOR)

  # GameType -> Username -> GetArchiveCallback
  getArchives: (type, username, callback) ->
    @redis.zrange @key(type, username), 0, -1, (err, reply) ->
      if err
        log.error 'redis.getArchives() failed',
          err: err
          id: id
        callback err
      else
        callback null, reply.map(safeParse)

  # waitingListAdd :: (Game) -> (Err -> Data -> _) -> _
  waitingListAdd: (game, callback) ->
    
  # waitingListRem :: (Game) -> (Err -> Data -> _) -> _
  waitingListRem: (game, callback) ->

  # GameType -> Username -> GameRank -> (Err -> Data -> _) -> _
  archiveGame: (type, username, gameRank, callback) ->
    k = @key type, username
    d = roundedDate gameRank.game?.date
    v = JSON.stringify gameRank
    @redis.zadd k, d, v, callback

  # GameType -> Username -> Timestamp -> (Err -> Data -> _) -> _
  unarchiveGame: (type, username, date, callback) ->
    k = @key type, username
    d = roundedDate date
    @redis.zremrangebyscore k, d, d, callback

  getLevel: (type, username, date, callback) ->
    k = @key type, username
    d = roundedDate date
    @redis.zrevrangebyscore [
      k, d, 0, 'LIMIT', 0, 1
    ], (err, response) ->
      if err
        callback err
      else
        try
          gameRank = JSON.parse response
        catch e
          callback e
        callback null, gameRank.outcome.newLevel

  # Get the level of all players at a given date
  # used to compute the ranking
  getAllLevels: (type, date, callback) ->
    @redis.keys

  # GameType -> Username -> Level -> Void
  saveLevel: (type, username, level, callback) ->
    @redis.zadd(
      @key(type, LEADERBOARD_KEY)
      level
      username
      callback
    )

  getRank: (type, username, callback) ->
    @redis.zrevrank @key(type, LEADERBOARD_KEY), username, callback

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

  saveLastSeq: (value, callback) ->
    @redis.set @key("lastseq"), value, callback

  incrGameIndex: (callback) ->
    @redis.incr @key("gameindex"), callback

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

