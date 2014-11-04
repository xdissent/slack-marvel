
Promise = require 'bluebird'


class ProjectSubscriber
  constructor: (@id, @socket) ->
    @channel = "prototype_#{@id}"

  subscribe: ->
    return @_unsubscribing.then(=> @subscribe()) if @_unsubscribing?
    @_subscribed ?= @socket.send
      event: 'pusher:subscribe', data: channel: @channel
    .then =>
      @socket.wait (msg) =>
        msg?.event is 'pusher_internal:subscription_succeeded' and
          msg?.channel is @channel
    .catch (err) =>
      @_subscribed = null
      Promise.reject err

  unsubscribe: ->
    return Promise.resolve() unless @_subscribed?
    subFailed = false
    @_unsubscribing ?= @_subscribed
      .catch ->
        subFailed = true
        Promise.resolve()
      .then =>
        if subFailed
          @_unsubscribing = null
          return Promise.resolve()
        @_subscribed = null
        @socket.send event: 'pusher:unsubscribe', data: channel: @channel
          .finally => @_unsubscribing = null


module.exports = ProjectSubscriber