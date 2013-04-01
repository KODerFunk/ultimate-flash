###*
 * Ultimate Flash 0.8.2 - Ruby on Rails oriented jQuery plugin for smart notifications
 * Copyright 2011-2013 Karpunin Dmitry (KODer) / Evrone.com
 * Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
 *
###

###*
 * $.fn.ultimateFlash() invoke Ultimate Flash functionality at first call on jQuery object
 * for the first element in the set of matched elements.
 * Subsequent calls forwarding on view methods or return view property.
 * If last argument {Boolean} true, then returns {Flash}.
 * @usage
 *   standart actions:
 *     construction    .ultimateFlash([Object options = {}])                  : {jQuery} jContainer
 *     updateOptions   .pluginName({Object} options)                          : {Object} view options
 *     get options     .pluginName('options')                                 : {Object} view options
 *     show            .ultimateFlash('show', String type, String text)       : {jQuery} jFlash | {Boolean} false
 *     notice          .ultimateFlash('notice', String text)                  : {jQuery} jFlash | {Boolean} false
 *     alert           .ultimateFlash('alert', String text)                   : {jQuery} jFlash | {Boolean} false
 *   extended actions:
 *     auto            .ultimateFlash('auto', {ArrayOrObject} obj)            : {Array} ajFlashes | {Boolean} false
 *     ajaxSuccess     .ultimateFlash('ajaxSuccess'[, Arguments successArgs = []])
 *     ajaxError       .ultimateFlash('ajaxError'[, String text = translations.defaultErrorText][, Arguments errorArgs = []])
###

# TODO improve English
# TODO jGrowl features

#= require ultimate/jquery-plugin-class
#= require ultimate/jquery-plugin-adapter

Ultimate.Plugins ||= {}

class Ultimate.Plugins.Flash extends Ultimate.Plugin

  el: '.l-page__flashes'

  @defaultLocales =
    en:
      defaultErrorText: 'Error'
      defaultThrownError: 'server connection error'
      formFieldsError: 'Form filled with errors'
    ru:
      defaultErrorText: 'Ошибка'
      defaultThrownError: 'ошибка соединения с сервером'
      formFieldsError: 'Форма заполнена с ошибками'

  flashClass: 'flash'                   # css-class of message container
  showAjaxErrors: true                  # catch global jQuery.ajaxErrors(), try detect message and show it
  showAjaxSuccesses: true               # catch global jQuery.ajaxSuccessess(), try detect message and show it
  preventUndefinedResponses: true       # prevent error responses with status code < 100, often 0
  detectFormErrors: true                # can be function (parsedJSON)
  detectPlainTextMaxLength: 200         # if response has plain text and its length fits, show it (-1 for disable)
  productionMode: true

  maxFlashes: 0                         # maximum flash messages in one time
  slideTime: 200                        # show and hide animate duration
  showTime: 3600                        # base time for show flash message
  showTimePerChar: 30                   # show time per char of flash message
  hideOnClick: true                     # click on notice fire hide()
  removeOnHide: true                    # remove notice DOM-element on hide
  forceAddDotsAfterLastWord: false
  forceRemoveDotsAfterLastWord: false
  regExpLastWordWithoutDot: /[\wа-яёА-ЯЁ]{3,}$/
  regExpLastWordWithDot: /([\wа-яёА-ЯЁ]{3,})\.$/

  events: ->
    _events = {}
    _events["click   .#{@flashClass}:not(:animated)"] = 'closeFlashClick'
    _events

  initialize: (options) ->
    # init flashes come from server in page
    @jFlashes().each (index, flash) =>
      jFlash = $(flash)
      jFlash.html @_prepareText(jFlash.html(), jFlash)
      @_setTimeout jFlash
    # binding hook ajaxError handler
    @$el.ajaxError =>
      if @showAjaxErrors
        a = @_ajaxParseArguments(arguments)
        @ajaxError a.data, a.jqXHR
    # binding hook ajaxSuccess handler
    @$el.ajaxSuccess =>
      if @showAjaxSuccesses
        a = @_ajaxParseArguments(arguments)
        @ajaxSuccess a.data, a.jqXHR

  # delegate event for hide on click
  closeFlashClick: (event) ->
    jFlash = $(event.currentTarget)
    if @_getOptionOverFlash('hideOnClick', jFlash)
      @hide jFlash
      false

  jFlashes: (filterSelector) ->
    _jFlashes = @$(".#{@flashClass}")
    if filterSelector then _jFlashes.filter(filterSelector) else _jFlashes

  _getOptionOverFlash: (optionName, jFlashOrOptions = {}) ->
    option = if jFlashOrOptions instanceof jQuery then jFlashOrOptions.data(optionName) else jFlashOrOptions[optionName]
    option ? @[optionName]

  _prepareText: (text, jFlashOrOptions) ->
    text = _.string.clean(text)
    # Add dot after last word (if word has minimum 3 characters)
    if @_getOptionOverFlash('forceAddDotsAfterLastWord', jFlashOrOptions) and @_getOptionOverFlash('regExpLastWordWithoutDot', jFlashOrOptions).test(text)
      text += '.'
    # Remove dot after last word (if word has minimum 3 characters)
    if @_getOptionOverFlash('forceRemoveDotsAfterLastWord', jFlashOrOptions)
      text = text.replace(@_getOptionOverFlash('regExpLastWordWithDot', jFlashOrOptions), '$1')
    text

  _setTimeout: (jFlash, timeout) ->
    timeout ?= @_getOptionOverFlash('showTime', jFlash) + jFlash.text().length * @_getOptionOverFlash('showTimePerChar', jFlash)
    if timeout
      jFlash.data 'timeoutId', setTimeout =>
        jFlash.removeData 'timeoutId'
        @hide jFlash
      , timeout

  hide: (jFlashes = @jFlashes()) ->
    jFlashes.each (index, element) =>
      jFlash = $(element)
      clearTimeout jFlash.data('timeoutId')
      jFlash.addClass('hide').slideUp @_getOptionOverFlash('slideTime', jFlash), =>
        jFlash.remove()  if @_getOptionOverFlash('removeOnHide', jFlash)

  _append: (jFlash) ->
    jFlash.appendTo @$el

  show: (type, text, timeout = null, perFlashOptions = null) ->
    text = @_prepareText(text, perFlashOptions)
    return false  if not _.isString(text) or _.string.isBlank(text)
    if @maxFlashes
      jActiveFlashes = @jFlashes(':not(.hide)')
      excessFlashes = jActiveFlashes.length - (@maxFlashes - 1)
      if excessFlashes > 0
        @hide jActiveFlashes.slice(0, excessFlashes)
    jFlash = $("<div class=\"#{@flashClass} #{type}\" style=\"display: none;\">#{text}</div>")
    @_append(jFlash).slideDown @_getOptionOverFlash('slideTime', perFlashOptions)
    if perFlashOptions
      jFlash.data(key, value)  for key, value of perFlashOptions
    @_setTimeout jFlash, timeout
    jFlash

  notice: (text, timeout = null, perFlashOptions = null) -> @show 'notice', arguments...

  alert:  (text, timeout = null, perFlashOptions = null) -> @show 'alert',  arguments...

  auto: (obj) ->
    if _.isArray(obj)
      @show(pair[0], pair[1])  for pair in obj
    else if $.isPlainObject(obj)
      @show(key, text)  for key, text of obj
    else false

  _ajaxParseArguments: (args) ->
    # detect event as first element
    if args[0] instanceof jQuery.Event
      # convert arguments to Array
      args = _.toArray(args)
      # remove event
      args.shift()
    # arrange arguments
    if _.isString(args[0])
      # from jQuery.ajax().success()
      [data, _textStatus, jqXHR] = args
    else
      # from jQuery.ajaxSuccess() or jQuery.ajaxError()
      [jqXHR, _ajaxSettings, data] = args
    data: data
    jqXHR: jqXHR

  ###*
   * @param  {String|Object} data       some data from ajax response
   * @param  {jqXHR} jqXHR              jQuery XHR
   * @return {Boolean}                  статус выполнения показа сообщения
  ###
  # MAYBE jqXHR set default as jQuery.hxr or similar
  ajaxSuccess: (data, jqXHR) ->
    # prevent recall
    return false  if jqXHR.breakFlash
    jqXHR.breakFlash = true
    # detect notice
    if _.isString(data)
      # catch plain text message
      data = _.string.trim(data)
      return @notice(data)  if data.length <= @detectPlainTextMaxLength and not $.isHTML(data)
    else if _.isObject(data)
      # catch json data with flash-notice
      return @auto(data['flash'])  if data['flash']
    false

  ###*
   * @param  {String}    [text='Ошибка']   вступительный (либо полный) текст формируемой ошибки
   * @param  {String}     thrownError      some error from ajax response
   * @param  {jqXHR}      jqXHR            jQuery XHR
   * @return {Boolean}                     статус выполнения показа сообщения
  ###
  ajaxError: (text, thrownError, jqXHR) ->
    unless _.isObject(jqXHR)
      jqXHR = thrownError
      thrownError = text
      text = @t('defaultErrorText')
    # prevent undefined responses
    return false  if @preventUndefinedResponses and jqXHR.status < 100
    # prevent recall
    return false  if jqXHR.breakFlash
    jqXHR.breakFlash = true
    if jqXHR.responseText
      try
        # try parse respose as json
        if parsedJSON = $.parseJSON(jqXHR.responseText)
          # catch 'flash' object and call auto() method with autodetecting flash-notice type
          return @auto(parsedJSON['flash'])  if parsedJSON['flash']
          # catch 'error' object and call alert() method
          return @alert(parsedJSON['error'])  if parsedJSON['error']
          # may be parsedJSON is form errors
          if @detectFormErrors is true
            # show message about form with errors
            return @alert(@t('formFieldsError'))
          else if _.isFunction(@detectFormErrors)
            # using showFormError as callback
            return @detectFormErrors.apply(@, [parsedJSON])
          else
            # nothing
            return false
      catch e
        # nop
    if @productionMode
      thrownError = @t('defaultThrownError')
    else
      if jqXHR.status >= 400 and jqXHR.responseText
        # try detect Rails raise message
        if raiseMatches = jqXHR.responseText.match(/<\/h1>\n<pre>(.+?)<\/pre>/)
          thrownError = raiseMatches[1]
        else
          # try detect short text message as error
          if not _.string.isBlank(jqXHR.responseText) and jqXHR.responseText.length <= @detectPlainTextMaxLength
            thrownError = jqXHR.responseText
      else if _.string.isBlank(thrownError)
        thrownError = @t('defaultThrownError')
    text += ': '  if text
    text += "#{thrownError} [#{jqXHR.status}]"
    @alert(text)



Ultimate.createJQueryPlugin 'ultimateFlash', Ultimate.Plugins.Flash
