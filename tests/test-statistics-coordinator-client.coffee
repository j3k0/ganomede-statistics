expect = require 'expect.js'
CoordinatorClient = require '../src/statistics/coordinator-client'

notCalled = -> throw new Error('should not be called')
called = ->
  f = ->
    f.callArguments = arguments
    f.called = true

describe 'statistics.coordinator-client', ->

  describe 'create', ->
    it 'returns a CoordinatorClient', ->
      expect(CoordinatorClient.create({})).to.be.a CoordinatorClient

  describe 'gameoverPath', ->
    it 'create the endpoint', ->
      jsonClient = {url:pathname:"/a"}
      path = CoordinatorClient._gameoverPath jsonClient, "1235", 4
      expect(path).to.eql "/a/gameover?secret=1235&since=4"

  describe 'gameoverHandler', ->
    it 'calls reject on error', ->
      h = CoordinatorClient._gameoverHandler(a = called(), notCalled)
      h(new Error("dummy"))
      expect(a.called).to.be true
      expect(a.callArguments[0].message).to.eql "dummy"
    it 'calls reject on status != 200', ->
      h = CoordinatorClient._gameoverHandler(b = called(), notCalled)
      h(null, null, {statusCode:400})
      expect(b.called).to.be true
      expect(b.callArguments[0].message).to.eql "HTTP400"
    it 'calls resolve with the body', ->
      h = CoordinatorClient._gameoverHandler(notCalled, c = called())
      h(null, null, {statusCode:200}, "snoopy")
      expect(c.called).to.be true
      expect(c.callArguments[0]).to.eql "snoopy"

# vim: ts=2:sw=2:et:

