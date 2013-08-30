$('li.facet').on 'click', 'a', ->

  facet_hidden_input = $('input#' + $(this).attr('data-facet-name'))
  $(facet_hidden_input).val($(this).attr('data-value'))

  $parent = $(this).parent()
  $grandparent = $(this).parents('.dropdown')

  if $parent.hasClass('active')
    $parent.removeClass('active')
    $grandparent.removeClass('active')

  else
    $parent.addClass('active')
    $grandparent.addClass('active')

    ## Only allow one active child
    ## Remove all other active siblings
    $parent.siblings().each ->
      if $(this).hasClass('active')
        $(this).removeClass('active')

clearEmptyParameters = ->
  $('form#facets-form').find('input[type="hidden"]').each (_, element) ->
    if $(element).val() == ''
      $(element).remove()

createHiddenTermInput = (term, value) ->
  term_input = $('<input />')
    .attr({'type': 'hidden', 'name': term, 'value': value})

cloneGlobalSearch = (context) ->
  value = $('input#search').val()
  term_input = createHiddenTermInput('term', value)
  $(context).append(term_input)

cloneAdvancedSearch = (context) ->
  $('.field-group input').each (_, element) ->
    name = $(element).attr('name')
    value = $(element).val()
    term_input = createHiddenTermInput(name, value)
    $(context).append(term_input)

$('form#facets-form').on 'submit', ->
  clearEmptyParameters()

  if $('.advanced-search:visible').length > 0
    cloneAdvancedSearch(this)
  else
    cloneGlobalSearch(this)

$('.sort-order ol.dropdown-menu a').click (event)->
  event.preventDefault()
  $('.sort-order a.dropdown-toggle').text($(this).attr('data-label'))
  $('.sort_by_field').val(
    $(this).attr('data-value')
  )
