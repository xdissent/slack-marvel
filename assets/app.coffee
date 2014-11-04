ids = window.location.hash.replace('#', '').split ','
unless ids.length > 0 and ids[0].length > 0
  $('.show-all').hide()
else
  $('.show-all').fadeIn('slow').click (evt) ->
    $('.prototype-screen').fadeIn('slow')
    $('.show-all').fadeOut('slow')
  $('.prototype-screen').each ->
    el = $ @
    id = el.data 'prototype-screen-id'
    el.hide() unless id.toString() in ids