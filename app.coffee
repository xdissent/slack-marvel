
fs = require 'fs'
path = require 'path'
http = require 'http'
jade = require 'jade'
sass = require 'node-sass'
coffee = require 'coffee-script'
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
    @batch = parseInt(process.env.SLACK_MARVEL_BATCH ? 120000)
    @socket = new MarvelSocket
    @port = parseInt(process.env.SLACK_MARVEL_PORT ? 80, 10)
    @_queued = {}

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
      plural = "screen#{if images.length > 1 then 's' else ''}"
      text = "#{link} updated #{images.length} #{plural}:\n"
      text += ("<#{img.url}|#{img.name}>" for img in images).join '\n'
      imageIds = (img.id for img in images).join ','
      editUrl = "https://marvelapp.com/manage/project/#{project.id}/"
      links =
        updated: "<#{@url}##{imageIds}|View Updated Screens>"
        all: "<#{@url}|View All Screens>"
        prototype: "<#{project.vanity_url}|View Prototype>"
        edit: "<#{editUrl}|Edit Prototype>"
      data =
        token: @token
        channel: @channel
        text: text
        username: @username
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

  queue: (image) ->
    clearTimeout @_timer if @_timer?
    @_queued[image.id] = image
    @_timer = setTimeout =>
      @_timer = null
      images = (v for _, v of @_queued)
      @_queued = {}
      debug 'Notifying', images
      @notify(images).then =>
        debug 'Clearing cached project'
        @_project = null
    , @batch

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
    debug 'Queueing', image
    @queue image

  html: ->
    @_html ?= new Promise (resolve, reject) ->
      src = path.resolve __dirname, 'assets/app.jade'
      fs.readFile src, encoding: 'utf8', (err, data) ->
        return reject err if err?
        try
          html = jade.compile data, filename: src
        catch err
          return reject err
        resolve html

  scripts: ->
    @_scripts ?= new Promise (resolve, reject) ->
      src = path.resolve __dirname, 'assets/app.coffee'
      fs.readFile src, encoding: 'utf8', (err, data) ->
        return reject err if err?
        try
          scripts = coffee.compile data
        catch err
          return reject err
        resolve scripts

  styles: ->
    @_styles ?= new Promise (resolve, reject) ->
      src = path.resolve __dirname, 'assets/app.sass'
      sass.render file: src, success: resolve, error: reject

  _handle: (req, res) =>
    if req.url is '/favicon.ico'
      res.writeHead 200, 'Content-Type': 'image/x-icon'
      return res.end()

    if req.url is '/app.js'
      debug 'Getting Scripts'
      return @scripts().then (scripts) ->
        debug 'Serving Scripts'
        res.writeHead 200, 'Content-Type': 'application/javascript'
        res.end scripts
      .catch (err) ->
        res.writeHead 500, 'Content-Type': 'text/plain'
        res.end err?.message ? 'Unknown error'

    if req.url is '/app.css'
      debug 'Getting Styles'
      return @styles().then (styles) ->
        debug 'Serving Styles'
        res.writeHead 200, 'Content-Type': 'text/css'
        res.end styles
      .catch (err) ->
        res.writeHead 500, 'Content-Type': 'text/plain'
        res.end err?.message ? 'Unknown error'

    debug 'Getting Styles'
    @project().then (project) =>
      @html().then (html) ->
        debug 'Serving html'
        res.writeHead 200, 'Content-Type': 'text/html'
        res.end html project: project
      .catch (err) ->
        res.writeHead 500, 'Content-Type': 'text/plain'
        res.end err?.message ? 'Unknown error'

  server: ->
    @_server ?= Promise.resolve http.createServer(@_handle).listen @port

  run: ->
    debug 'Starting server'
    @server().then =>
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
