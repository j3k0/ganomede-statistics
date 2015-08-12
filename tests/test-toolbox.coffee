expect = require 'expect.js'
Maybe = require 'data.maybe'

describe 'toolbox', ->

  describe 'clone', ->
    clone = require('../src/toolbox').clone
    it 'clones an object', ->
      expect(clone {a:1}).to.eql {a:1}
      expect(clone(x = {a:1})).not.to.be x

  describe 'extend', ->
    extend = require('../src/toolbox').extend
    it 'extends the fields of an object', ->
      expect(extend {a:1}, {b:2}).to.eql {a:1, b:2}
    it 'overrides the first objects properties', ->
      expect(extend {a:1,b:2}, {b:3}).to.eql {a:1, b:3}
    it 'does not change the source objects', ->
      x = a:1, b:2
      y = b:3
      z = extend(x,y)
      expect(x).to.eql a:1,b:2
      expect(y).to.eql b:3
      expect(z).to.eql a:1,b:3

  describe 'monadsChain', ->
    monadsChain = require('../src/toolbox').monadsChain
    init = ()  -> Maybe.of(1)
    f    = (x) -> Maybe.fromNullable(x)
    testChain = monadsChain init, f
    it 'returns the initial monad for an empty array', ->
      expect(testChain([]).get()).to.eql 1
    it 'chains monads', ->
      expect(testChain([2]).get()).to.eql 2
      expect(testChain([2,3]).get()).to.eql 3
      expect(testChain([2]).isNothing).to.be false
      expect(testChain([2,null]).isNothing).to.be true
      expect(testChain([null,2]).isNothing).to.be true

# vim: ts=2:sw=2:et:
