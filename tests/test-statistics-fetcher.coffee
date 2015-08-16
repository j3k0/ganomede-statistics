expect = require 'expect.js'
Fetcher = require '../src/statistics/fetcher'
Task = require 'data.task'

nop = ->
notCalled = -> throw new Error('should not be called')
called = ->
  f = ->
    f.callArguments = arguments
    f.called = true

testGame = (id) ->
  id: id
  type: "tigger/v1"
  gameOverData:
    players: [{
      name: "jeko",
      score: 21
    }, {
      name: "sousou",
      score: 20
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

testGamesBody =
  last_seq: 10
  results: [
    testGame("1")
    testGame("2")
    testGame("3")
  ]

fakeClient = ->
  gameover: Task.of testGamesBody

fakeStorage = ->
  archives: { jeko:[], sousou:[] }
  key: (type,username) -> "#{type}/#{username}"
  archiveGameArgs: []
  archiveGame: (type, username, game, callback) ->
    a = @archives[@key(type,username)] ||
      (@archives[@key(type,username)] = [])
    a.push game
    @archiveGameArgs.push [type,username,game]
    callback null, null
  saveLevel: (t,u,l,callback) -> callback null, null
  getRank: (t,u,callback) -> callback null, 12
  getArchives: (type, username, callback) ->
    a = @archives[@key(type,username)]
    if !a then return callback null, []
    if username == "jeko"
      callback null, @archives[@key(type, username)]
    else if username == "sousou"
      callback null, @archives[@key(type, username)]
    else
      callback new Error("error")
  incrGameIndex: (callback) ->
    callback null, @gameindex = ((@gameindex || 0) + 1)

describe 'statistics.fetcher', ->

  describe 'create', ->
    it 'returns a Fetcher', ->
      expect(Fetcher.create(host:"localhost",port:1024,null)).to.be.a Fetcher

  describe 'addGame', ->
    it 'computes the outcome of a game', ->
      outcomes = Fetcher._addGame
        game: testGame "dummy"
        archives: []
      expect(outcomes).to.be.an Array
      expect(outcomes.length).to.eql 2
      expect(outcomes[0].username).to.eql "jeko"
      expect(outcomes[0].type).to.eql "tigger/v1"
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

  describe 'processGamesBody', ->
    it 'saves all games', (done) ->
      storage = fakeStorage()
      state = secret:"1234", last_seq:5
      task = Fetcher._processGamesBody(storage, state) testGamesBody
      expect(task).to.be.a Task
      task.fork(
        notCalled
        (newSince) ->
          # expect(newState.secret).to.eql "1234"
          expect(newSince).to.eql testGamesBody.last_seq
          ja = storage.archives["tigger/v1/jeko"]
          sa = storage.archives["tigger/v1/sousou"]
          expect(ja.length).to.eql 3
          expect(sa.length).to.eql 3
          expect(ja[ja.length-1].outcome.newLevel).to.eql 87
          expect(sa[sa.length-1].outcome.newLevel).to.eql 15
          done()
      )

# vim: ts=2:sw=2:et:
