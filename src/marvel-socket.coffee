
Promise = require 'bluebird'
WebSocket = require 'ws'
debug = require('debug') 'slack-marvel'

MARVEL_APP_ID = '70744d379f87a37df68a'
MARVEL_WS_PATH = "wss://ws.pusherapp.com/app/#{MARVEL_APP_ID}"
MARVEL_WS_QUERY = "protocol=7&client=js&version=2.2.3&flash=false"
MARVEL_WS_URL = "#{MARVEL_WS_PATH}?#{MARVEL_WS_QUERY}"


class MarvelSocket
  socket: ->
    @_socket ?= Promise.resolve(new WebSocket MARVEL_WS_URL).then (socket) ->
      socket.on 'open', -> debug 'OPEN', arguments...
      socket.on 'message', (msg) -> debug 'RECV', msg
      socket.on 'error', (err) -> debug 'ERR', err
      socket.on 'close', -> debug 'CLOSE', arguments...

  connect: -> @_connected ?= @socket().then (socket) =>
    @_wait (msg) -> msg?.event is 'pusher:connection_established'

  send: (msg) -> @connect().then => @socket().then (socket) ->
    new Promise (resolve, reject) ->
      debug 'SEND', msg
      socket.send JSON.stringify(msg), (err) ->
        return reject err if err?
        resolve()

  wait: (args...) -> @connect().then => @_wait args...

  _wait: (match, errorMatch, timeout = 10000) ->
    errorMatch ?= (msg) -> msg?.event is 'pusher:error'

    @socket().then (socket) -> new Promise (_resolve, _reject) ->
      guard = false
      timer = null

      resolve = ->
        return if guard
        guard = true
        unload()
        _resolve arguments...

      reject = ->
        return if guard
        guard = true
        unload()
        _reject arguments...

      listener = (msg) ->
        try
          msg = JSON.parse msg
        catch err
          return reject err
        return reject msg if errorMatch msg
        resolve msg if match msg

      load = ->
        timer = setTimeout ->
          reject timeout: timeout
        , timeout
        socket.once 'message', listener
        socket.once 'error', reject

      unload = ->
        clearTimeout timer
        socket.removeListener 'message', listener
        socket.removeListener 'error', reject

      load()


module.exports = MarvelSocket