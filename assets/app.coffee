ids = window.location.hash.replace('#', '').split ','
unless ids.length > 0 and ids[0].length > 0
  $('.show-all').hide()
else
  $('.show-all').fadeIn('slow').click (evt) ->
    $('.project-image').fadeIn('slow')
    $('.show-all').fadeOut('slow')
  $('.project-image').each ->
    el = $ @
    id = el.data 'image-id'
    el.hide() unless id.toString() in ids


modal = $ '#project-image-modal'
modalDialog = modal.find '.modal-dialog'
modalContent = modal.find '.modal-content'
modalBody = modal.find '.modal-body'
modalTitle = modal.find '.title'
modalDirectory = modal.find '.directory'
modalMargin = 120

imageWidth = 0
imageHeight = 0

$('.project-image a').click (evt) ->
  evt.preventDefault()
  link = $ @
  image = link.closest '.project-image'

  modalBody.html "<img src=\"#{link.attr 'href'}\">"
  modalTitle.html image.data 'image-name'
  modalDirectory.html image.data 'image-directory'

  imageWidth = parseInt image.data 'image-width'
  imageHeight = parseInt image.data 'image-height'

  resize()

  modal.modal 'show'

resize = ->
  contentHeight = $(window).height() - modalMargin
  contentWidth = $(window).width() - modalMargin
  
  scale = Math.min contentWidth / imageWidth, contentHeight / imageHeight
  scale = 1 if scale > 1

  scaledWidth = scale * imageWidth
  scaledHeight = scale * imageHeight

  modalContent.css 'max-height', contentHeight
  modalBody.css 'max-height', contentHeight
  modalDialog.css 
    'margin-left':-(scaledWidth / 2)
    'margin-top': -(scaledHeight / 2)

$(window).resize resize
