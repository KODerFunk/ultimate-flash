###*
 * Ultimate Flash 0.9.2 - Ruby on Rails oriented jQuery plugin for smart notifications
 * Copyright 2011-2013 Karpunin Dmitry (KODer) / Evrone.com
 * Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
 *
###

###*
 * * * DEPRECATED syntax!
 *
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
 *
 * * * USE INSTEAD
 * @usage
 *   window.flash = new Ultimate.Plugins.Flash[(Object options = {})]
 *   flash.notice String text
###

# TODO improve English
# TODO jGrowl features

#= require ultimate/jquery-plugin-adapter

Ultimate.Plugins ||= {}

Ultimate.__FlashClass ||= Ultimate.Plugin

class Ultimate.Plugins.Flash extends Ultimate.__FlashClass

  el: '.l-page__flashes'

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
  hiddenClass: 'hidden-flash'           # class to add for hidden flashes
  hideOnClick: true                     # click on notice fire hide()
  removeAfterHide: true                 # remove notice DOM-element on hide
  forceAddDotsAfterLastWord: false
  forceRemoveDotsAfterLastWord: false
  regExpLastWordWithoutDot: /[\wа-яёА-ЯЁ]{3,}$/
  regExpLastWordWithDot: /([\wа-яёА-ЯЁ]{3,})\.$/

  events: ->
    _events = {}
    _events["click   .#{@flashClass}:not(:animated)"] = 'closeFlashClick'
    _events

  initialize: (options) ->
    @_initTranslations options
    # init flashes come from server in page
    @jFlashes().each (index, flash) =>
      jFlash = $(flash)
      jFlash.html @_prepareText(jFlash.html(), jFlash)
      @_setTimeout jFlash
    jDocument = $(document)
    # binding hook ajaxError handler
    jDocument.ajaxError =>
      if @showAjaxErrors
        a = @_ajaxParseArguments(arguments)
        @ajaxError a.data, a.jqXHR
    # binding hook ajaxSuccess handler
    jDocument.ajaxSuccess =>
      if @showAjaxSuccesses
        a = @_ajaxParseArguments(arguments)
        @ajaxSuccess a.data, a.jqXHR



  locale: 'en'
  translations: null

  @defaultLocales =
    en:
      defaultErrorText: 'Error'
      defaultThrownError: 'server connection error'
      formFieldsError: 'Form filled with errors'
    ru:
      defaultErrorText: 'Ошибка'
      defaultThrownError: 'ошибка соединения с сервером'
      formFieldsError: 'Форма заполнена с ошибками'

  # use I18n, and modify locale and translations
  _initTranslations: (options) ->
    @translations ||= {}
    if not options['locale'] and I18n?.locale of @constructor.defaultLocales
      @locale = I18n.locale
    _.defaults @translations, @constructor.defaultLocales[@locale]

  t: (key) ->
    @translations[key] or _.string.humanize(key)

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

  _hide: (jFlash, slideTime) ->
    jFlash.slideUp slideTime, =>
      jFlash.remove()  if @_getOptionOverFlash('removeAfterHide', jFlash)

  hide: (jFlashes = @jFlashes()) ->
    jFlashes.each (index, element) =>
      jFlash = $(element)
      clearTimeout jFlash.data('timeoutId')
      @_hide jFlash.addClass(@hiddenClass), @_getOptionOverFlash('slideTime', jFlash)

  _template: (type, text) ->
    "<div class=\"#{@flashClass} #{type}\" style=\"display: none;\">#{text}</div>"

  _append: (jFlash) ->
    jFlash.appendTo @$el

  _show: (jFlash, slideTime) ->
    jFlash.slideDown slideTime

  show: (type, text, timeout = null, perFlashOptions = null) ->
    text = @_prepareText(text, perFlashOptions)
    return false  if not _.isString(text) or _.string.isBlank(text)
    if @maxFlashes
      jActiveFlashes = @jFlashes(":not(.#{@hiddenClass})")
      excessFlashes = jActiveFlashes.length - (@maxFlashes - 1)
      if excessFlashes > 0
        @hide jActiveFlashes.slice(0, excessFlashes)
    jFlash = $(@_template(type, text))
    if perFlashOptions
      jFlash.data(key, value)  for key, value of perFlashOptions
    @_show @_append(jFlash), @_getOptionOverFlash('slideTime', perFlashOptions)
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
        parsedJSON = $.parseJSON(jqXHR.responseText)
        if _.isObject(parsedJSON) and not _.isEmpty(parsedJSON)
          # catch 'flash' object and call auto() method with autodetecting flash-notice type
          return @auto(parsedJSON['flash'])  if parsedJSON['flash']
          # catch 'error' object and call alert() method
          return @alert(parsedJSON['error'])  if parsedJSON['error']
          # may be parsedJSON is form errors
          if @detectFormErrors is true
            # show message about form with errors
            return @alert(@t('formFieldsError'))
          else if _.isFunction(@detectFormErrors) and (detectedError = @detectFormErrors(parsedJSON))
            # using detectFormErrors as callback
            return @alert(detectedError)
          else
            # nothing
            return false
      catch e
        # nop
    # about 404: https://github.com/bcardarella/client_side_validations/issues/297
    return false  if jqXHR.status < 400 or jqXHR.status is 404
    if @productionMode
      thrownError = @t('defaultThrownError')
    else
      if jqXHR.responseText
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
