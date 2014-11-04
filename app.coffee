
request = require 'request'
Promise = require 'bluebird'
debug = require('debug') 'slack-marvel'

MarvelSocket = require './src/marvel-socket.coffee'
ProjectSubscriber = require './src/project-subscriber.coffee'

SLACK_API_URL = 'https://slack.com/api/chat.postMessage'


class App
  constructor: ->
    @vanity = process.env.SLACK_MARVEL_ID ? throw new Error 'ID required'
    @token = process.env.SLACK_MARVEL_TOKEN ? throw new Error 'Token required'
    @url = process.env.SLACK_MARVEL_URL ? 'http://example.com'
    @channel = process.env.SLACK_MARVEL_CHANNEL ? '#general'
    @username = process.env.SLACK_MARVEL_USERNAME ? 'Marvel'
    @socket = new MarvelSocket

  project: -> @_project ?= new Promise (resolve, reject) =>
    url = "https://marvelapp.com/api/prototype/#{@vanity}/?xf="
    debug 'Requesting', url
    request url, (err, res, body) ->
      debug 'Resonse', url, err, body
      return reject err if err?
      return reject 'Bad Status' unless res.statusCode is 200
      try
        project = JSON.parse body
      catch err
        return reject 'Invalid JSON'
      return reject 'Missing ID' unless project?.id?
      resolve project

  subscriber: -> @_subscriber ?= @project().then (project) =>
    new ProjectSubscriber project.id, @socket

  notify: (images) ->
    @project().then (project) =>
      link = "*<#{project.vanity_url}|#{project.name}>*"
      text = "#{link} updated #{images.length} screens:\n"
      text += ("<#{img.url}|#{img.name}>" for img in images).join '\n'
      imageIds = (img.id for img in images).join ','
      editUrl = "https://marvelapp.com/manage/project/#{project.id}/"
      links =
        updated: "<#{@url}?screens=#{imageIds}|View Updated Screens>"
        all: "<#{@url}?project=#{@vanity}|View All Screens>"
        prototype: "<#{project.vanity_url}|View Prototype>"
        edit: "<#{editUrl}|Edit Prototype>"
      data =
        token: @token
        channel: @channel
        text: text
        username: 'Marvel'
        attachments: JSON.stringify [
          fallback: ''
          color: '#28d87e'
          text: (v for _, v of links).join '  |  '
        ]
      data.icon_url = project.app_icon.url if project.app_icon?.url?

      new Promise (resolve, reject) ->
        debug 'Posting', data
        request.post SLACK_API_URL, form: data, (err, res, body) ->
          debug 'Posted', err, body
          resolve()

  listener: (project) -> (msg) =>
    try
      msg = JSON.parse msg
    catch err
    return unless msg?.event is 'event_image'
    return unless msg?.channel is "prototype_#{project.id}"
    try
      data = JSON.parse msg.data
    catch err
    image = data?.content?.object
    return unless image?.status is 5
    debug 'Notifying', image
    @notify [image]
  
  run: ->
    debug 'Getting Project', @vanity
    @project().then (project) =>
      debug 'Socketing'
      @socket.socket().then (socket) =>
        socket.on 'message', @listener project
        debug 'Listening'
        @subscriber().then (subscriber) ->
          debug 'Subscribing'
          subscriber.subscribe().then ->
            debug 'Subscribed'


app = new App
debug 'Running'
app.run().then ->
  debug 'Run finished'
