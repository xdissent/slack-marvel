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

modal = $ '#prototype-screen-modal'

$('.prototype-screen a').click (evt) ->
  evt.preventDefault()
  link = $ @
  screen = link.closest '.prototype-screen'
  src = link.attr 'href'
  title = screen.data 'prototype-screen-name'
  directory = screen.data 'prototype-screen-directory'
  $('.modal-body', modal).html "<img class=\"ximg-responsive\" src=\"#{src}\">"
  $('.modal-title', modal).html title
  $('.directory', modal).html directory
  adjustModalMaxHeightAndPosition()
  modal.modal 'show'

adjustModalMaxHeightAndPosition = ->
  modal.show() unless modal.hasClass 'in'
  contentHeight = $(window).height() - 120
  modal.find('.modal-content').css 'max-height': -> contentHeight
  modal.find('.modal-body').css 'max-height': -> contentHeight
  modal.find('.modal-dialog').addClass('modal-dialog-center').css
    'margin-top': -> -($(this).outerHeight() / 2)
    'margin-left': -> -($(this).outerWidth() / 2)
  modal.hide() unless modal.hasClass 'in'

if $(window).height() >= 320
  $(window).resize(adjustModalMaxHeightAndPosition).trigger 'resize'
