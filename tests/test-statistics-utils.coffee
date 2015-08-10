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

  describe 'clone', ->
    it 'clones an object', ->
      expect(utils.clone {a:1}).to.eql {a:1}
      expect(utils.clone(x = {a:1})).not.to.be x

  describe 'extend', ->
    it 'extends the fields of an object', ->
      expect(utils.extend {a:1}, {b:2}).to.eql {a:1, b:2}
    it 'overrides the first objects properties', ->
      expect(utils.extend {a:1,b:2}, {b:3}).to.eql {a:1, b:3}
    it 'does not change the source objects', ->
      x = a:1, b:2
      y = b:3
      z = utils.extend(x,y)
      expect(x).to.eql a:1,b:2
      expect(y).to.eql b:3
      expect(z).to.eql a:1,b:3

  describe 'sendError', ->
    it 'sends the error and call next', ->
      expect(utils.sendError(nop,nop)).to.be.a Function
      utils.sendError(a=called(),b=called()) "dummy"
      expect(a.called).to.be true
      expect(b.called).to.be true

  describe 'getParams', ->
    it 'returns a Task', ->
      expect(utils.getParams(1,2,3)).to.be.a Task
    it 'resolves as follows', (done) ->
      req = params:
        gameType: "a"
        gameVersion: "b"
        username: "c"
      s = (data) ->
        expect(data.params.req).to.be req
        expect(data.params.res).to.eql 2
        expect(data.params.next).to.eql 3
        expect(data.gameType).to.eql "a/b"
        expect(data.username).to.eql "c"
        done()
      utils.getParams(req,2,3).fork notCalled,s

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
    it 'chains nicely with getParams', (done) ->
      req = params:
        gameType: "a"
        gameVersion: "b"
        username: "c"
      payload = gameType:"a/b", username:"c", params:
        req:req, res:2, next:3
      utils.getParams(req,2,3)
      .chain utils.checkParams
      .fork notCalled, expectSuccess(done, payload)
    it 'fails when chained with getParams', (done) ->
      req = params:
        gameVersion: "b"
        username: "c"
      utils.getParams(req,2,3)
      .chain utils.checkParams
      .fork expectError(done, 400), notCalled

  describe 'loadArchive', ->
    it 'is pending'

  describe 'getStats', ->
    it 'is pending'

# vim: ts=2:sw=2:et:
