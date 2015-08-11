expect = require 'expect.js'
utils = require '../src/endpoint'

nop = ->
notCalled = -> throw new Error('should not be called')
called = ->
  f = ->
    f.called = true

describe 'endpoint', ->

  describe 'sendError', ->
    it 'sends the error and call next', ->
      expect(utils.sendError(nop,nop)).to.be.a Function
      utils.sendError(a=called(),b=called()) "dummy"
      expect(a.called).to.be true
      expect(b.called).to.be true

# vim: ts=2:sw=2:et:
