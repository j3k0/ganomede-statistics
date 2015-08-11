expect = require 'expect.js'
fakeRedis = require 'fakeredis'
utils = require '../src/statistics/utils'
Task = require 'data.task'

nop = ->
notCalled = -> throw new Error('should not be called')
called = ->
  f = ->
    f.called = true

describe 'statistics.utils', ->

  describe 'readParams', ->
    it 'returns a Task', ->
      expect(utils.readParams(1,2,3)).to.be.a Task
    it 'resolves as follows', (done) ->
      params =
        gameType: "a"
        gameVersion: "b"
        username: "c"
      s = (data) ->
        expect(data.gameType).to.eql "a/b"
        expect(data.username).to.eql "c"
        done()
      utils.readParams(params).fork notCalled,s

  describe 'checkParams', ->
    expectError = (done,status) -> (err) ->
      expect(err.statusCode).to.eql status
      done()
    expectSuccess = (done,payload) -> (data) ->
      expect(data).to.eql payload
      done()
    it 'returns a Task', ->
      expect(utils.checkParams(null)).to.be.a Task
    it 'rejects missing username', (done) ->
      utils.checkParams(gameType: "game/v1")
      .fork expectError(done, 400), notCalled
    it 'rejects missing gameType', (done) ->
      utils.checkParams(username: "alihood")
      .fork expectError(done, 400), notCalled
    it 'rejects null', (done) ->
      utils.checkParams(null)
      .fork expectError(done, 400), notCalled
    it 'resolves valid payloads', (done) ->
      payload = gameType: "game/v1", username: "alice"
      utils.checkParams payload
      .fork notCalled, expectSuccess(done, payload)
    it 'chains nicely with readParams', (done) ->
      params =
        gameType: "a"
        gameVersion: "b"
        username: "c"
      payload = gameType:"a/b", username:"c"
      utils.readParams(params)
      .chain utils.checkParams
      .fork notCalled, expectSuccess(done, payload)
    it 'fails when chained with readParams', (done) ->
      params =
        gameVersion: "b"
        username: "c"
      utils.readParams(params)
      .chain utils.checkParams
      .fork expectError(done, 400), notCalled

  describe 'loadArchive', ->
    it 'is pending'

  describe 'getStats', ->
    it 'is pending'

  describe 'stats', ->

# vim: ts=2:sw=2:et:
