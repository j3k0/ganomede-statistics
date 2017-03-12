expect = require 'expect.js'
Storage = require '../src/statistics/storage'
redis = require 'fakeredis'

# Test data

id = 'game-id'
type = 'triplex/v2'
username0 = 'alice'
username1 = 'bob'
score0 = 4
score1 = 2
date = 123131121
newLevel = 1200
newRank = 99

playerScore0 = {username: username0, score: score0}
playerScore1 = {username: username1, score: score1}
players = [playerScore0, playerScore1]
game = {id, date, players}
outcome = {newLevel, newRank}
gameRank = {game, outcome}

describe 'statistics.Storage', ->

  storage = null
  redisClient = null
  prefix = 'whatever'

  beforeEach ->
    redisClient = redis.createClient()
    redisClient.flushdb()
    storage = new Storage redisClient, prefix

  afterEach ->
    redisClient.quit()

  describe '.key(parts...)', ->
    it 'generate a key from prefix and parts separated by ":"', ->
      expect(storage.key('hello', 'kitty')).to.equal 'whatever:hello:kitty'

  describe '.archiveGame(type, username, gameRank, callback)', ->
    it 'adds a game in redis', (done) ->
      k = storage.key type, username0
      redisClient.zcount k, date, date, (err, data) ->
        expect(data).to.equal 0
        storage.archiveGame type, username0, gameRank, (err, data) ->
          expect(err).to.be.null
          redisClient.zcount k, date, date, (err, data) ->
            expect(err).to.be.null
            expect(data).to.equal 1
            done()

  describe '.getArchives(type, username, callback)', ->
    it 'returns a empty array for a user with no game', (done) ->
      storage.getArchives type, username0, (err, games) ->
        expect(err).to.be.null
        expect(games).to.be.an(Array)
        expect(games.length).to.equal(0)
        done()

    it 'loads all games for a given user', (done) ->

      storage.archiveGame type, username0, gameRank, (err, data) ->
        storage.getArchives type, username0, (err, games) ->
          expect(err).to.be.null
          expect(games).to.be.an(Array)
          expect(games.length).to.equal(1)
          done()

  lockName = 'mylock'

  describe '.lock(lockName, callback)', ->
    it 'acquires a lock', (done) ->
      storage.lock lockName, (err) ->
        expect(err).to.be.null
        done()

  describe '.unlock(lockName, callback)', ->
    it 'releases a lock', (done) ->
      storage.unlock lockName, (err) ->
        expect(err).to.be.null
        done()

# vim: ts=2:sw=2:et:
