expect = require 'expect.js'
Fetcher = require '../src/statistics/fetcher'
Task = require 'data.task'
coordinatorGameOverFull = require './coordinator-gameover-full.json'
coordinatorGameOverShort = require './coordinator-gameover-short.json'
coordinatorGameOverNoDate= require './coordinator-gameover-nodate.json'
types = require '../src/statistics/types'
log = require '../src/log'

nop = ->
notCalled = (err) ->
  throw (err || new Error('should not be called'))
called = ->
  f = ->
    f.callArguments = arguments
    f.called = true

testScores =
  jeko:
    "dummy": 21
    "1": 21
    "2": 10
    "3": 42
  sousou:
    "dummy": 20
    "1": 20
    "2": 30
    "3": 40

testGame = (id) ->
  id: id
  date: parseInt(id) || 999
  type: "tigger/v1"
  gameOverData:
    players: [{
      username: "jeko"
      score: testScores.jeko[id]
    }, {
      username: "sousou"
      score: testScores.sousou[id]
    }]

testOutcomes = [{
  username:"jeko"
  game:
    game:
      id:"dummy"
      date:1439413599.78
      players:[{
        username:"jeko"
        score:21
      }, {
        username:"sousou"
        score:20
      }]
    outcome:
      newLevel:30
      newRank: 13
  type:"tigger/v1"
}, {
  username:"sousou"
  game:
    game:
      id:"dummy"
      date:1439413599.78
      players:[{
        username:"jeko"
        score:21
      },{
        username:"sousou"
        score:20
      }]
    outcome:
      newLevel:7
      newRank: 13
  type:"tigger/v1"
}]

testGamesBody = (i0, i1, i2) ->
  last_seq: 10
  results: [
    testGame(i0)
    testGame(i1)
    testGame(i2)
  ]

fakeClient = (testData) ->
  limit: 2048
  gameover: () -> Task.of(testData)

fakeStorage = ->
  archives: {}
  key: (type,username) -> "#{type}/#{username}"
  archiveGameArgs: []
  archiveGame: (type, username, game, callback) ->
    k = @key(type,username)
    a = @archives[k] || (@archives[k] = [])
    a.push game
    @archiveGameArgs.push [type,username,game]
    callback null, null
  unarchiveGameArgs: []
  unarchiveGame: (type, username, date, callback) ->
    k = @key(type,username)
    a = @archives[k] || (@archives[k] = [])
    @archives[k] = a.filter (game) ->
      game.game.date != date
    @unarchiveGameArgs.push [type,username,date]
    callback null, null
  saveLevel: (t,u,l,callback) -> callback null, null
  getRank: (t,u,callback) -> callback null, 12
  getArchives: (type, username, callback) ->
    k = @key(type,username)
    a = @archives[k] || (@archives[k] = [])
    callback null, @archives[@key(type, username)]
  incrGameIndex: (callback) ->
    callback null, @gameindex = ((@gameindex || 0) + 1)

describe 'statistics.fetcher', ->

  describe 'create', ->
    it 'returns a Fetcher', ->
      expect(Fetcher.create(host:"localhost",port:1024,null)).to.be.a Fetcher

  describe 'addGame', ->
    it 'computes the outcome of a game', ->
      dummyGame = testGame "dummy"
      outcomes = Fetcher._addGame
        game: dummyGame
        archives: []

      expect(outcomes).to.be.an Array
      expect(outcomes.length).to.eql 2
      expect(outcomes[0].username).to.eql "jeko"
      expect(outcomes[0].type).to.eql "tigger/v1"
      expect(outcomes[0].game.game.date).to.eql dummyGame.date
      expect(typeof outcomes[0].game.outcome.newLevel).to.eql "number"

  describe 'saveOutcomes', ->
    it 'saves all outcomes', (done) ->
      storage = fakeStorage()
      task = Fetcher._saveOutcomes(storage) testOutcomes
      expect(task).to.be.a Task
      task.fork(
        notCalled
        () ->
          args = storage.archiveGameArgs
          expect(args.length).to.eql 2
          expect(args[0][0]).to.eql "tigger/v1"
          expect(args[0][1]).to.eql "jeko"
          expect(args[0][2]).to.eql testOutcomes[0].game
          expect(args[1][0]).to.eql "tigger/v1"
          expect(args[1][1]).to.eql "sousou"
          expect(args[1][2]).to.eql testOutcomes[1].game
          done()
      )

  describe 'loadGames', ->
    testWith = (testData, done) ->
      task = Fetcher._loadGames(fakeClient(testData), null)(null)
      expect(task).to.be.a Task
      task.fork(
        notCalled
        (body) ->
          types.gamesBody body
          done()
      )
    it 'retrieve and format the games from couchdb (quick test)', (done) ->
      testWith coordinatorGameOverShort, done
    it 'fills up missing date', (done) ->
      testWith coordinatorGameOverNoDate, done
    it 'process many games quickly and without failing', (done) ->
      testWith coordinatorGameOverFull, done
    it 'sorts games by date', (done) ->
      task = Fetcher._loadGames(fakeClient(coordinatorGameOverFull), null)(null)
      task.fork(
        notCalled
        (body) ->
          lastDate = 0
          for game in body.results
            expect(game.date).not.to.be.below lastDate
            lastDate = game.date
          done()
      )

  describe 'processGamesBody', ->

    testCombination = (i0, i1, i2) -> (done) ->
      storage = fakeStorage()
      # state = secret:"1234", last_seq:5
      testData = testGamesBody i0, i1, i2
      task = Fetcher._processGamesBody(storage) testData
      expect(task).to.be.a Task
      task.fork(
        notCalled
        (newSince) ->
          # expect(newState.secret).to.eql "1234"
          expect(newSince).to.eql testData.last_seq
          ja = storage.archives["tigger/v1/jeko"]
          sa = storage.archives["tigger/v1/sousou"]
          expect(ja.length).to.eql 3
          expect(sa.length).to.eql 3
          expect(ja[ja.length-1].outcome.newLevel).to.eql 59
          expect(sa[sa.length-1].outcome.newLevel).to.eql 37
          done()
      )
    it 'saves games when sorted by date (1,2,3)', testCombination("1", "2", "3")
    it 'saves games in any orders (1,3,2)', testCombination("1", "3", "2")
    it 'saves games in any orders (2,1,3)', testCombination("2", "1", "3")
    it 'saves games in any orders (2,3,1)', testCombination("2", "3", "1")
    it 'saves games in any orders (3,1,2)', testCombination("3", "1", "2")
    it 'saves games in any orders (3,2,1)', testCombination("3", "2", "1")

# vim: ts=2:sw=2:et:
