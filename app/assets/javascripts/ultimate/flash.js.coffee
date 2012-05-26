###
 * Ultimate Flash 0.5.0 - Ruby on Rails oriented jQuery plugin based on Ultimate Widget System
 *
 * Copyright 2011-2012 Karpunin Dmitry (KODer) / Evrone.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
###

# TODO customizable show() and hide()
# TODO improve English
# TODO settings by call
# TODO jGrowl features

###
 * Invoke Ultimate Flash functionality for the first element in the set of matched elements.
 * If last argument {Boolean} true, then returns {Widget}.
 * @usage
 *** standart actions ***
 * construction    .ultimateFlash([Object options = {}])                  ~ {jQuery} jContainer
 * show            .ultimateFlash('show', String type, String text)       ~ {jQuery} jFlash | {Boolean} false
 * notice          .ultimateFlash('notice', String text)                  ~ {jQuery} jFlash | {Boolean} false
 * alert           .ultimateFlash('alert', String text)                   ~ {jQuery} jFlash | {Boolean} false
 *** extended actions ***
 * getSettings     .ultimateFlash('getSettings')                          ~ {Object} settings
 * setSettings     .ultimateFlash('setSettings', {Object} settings)       ~ {jQuery} jContainer
 * updateSettings  .ultimateFlash({Object} options)                       ~ {Object} settings
 * auto            .ultimateFlash('auto', {ArrayOrObject} obj)            ~ {Array} ajFlashes | {Boolean} false
 * ajaxSuccess     .ultimateFlash('ajaxSuccess'[, Arguments successArgs = []])
 * ajaxError       .ultimateFlash('ajaxError'[, String text = settings.translations.defaultErrorText][, Arguments errorArgs = []])
###



$ ->
  Ultimate.createPlugin Ultimate.Plugins.Flash, 'ultimateFlash'



class Ultimate.Plugins.Flash extends Ultimate.Proto.Widget
  @className: 'Flash'

  @selector: '.l-page__flashes'

  @defaults:
    locales:
     'en':
       defaultErrorText: 'Error'
       defaultThrownError: 'server connection error'
       formFieldsError: 'Form filled with errors'
     'ru':
       defaultErrorText: 'Ошибка'
       defaultThrownError: 'ошибка соединения с сервером'
       formFieldsError: 'Форма заполнена с ошибками'
    options:
      locale: 'en'
      translations: {}
      slideTime: 200
      showTime: 3600
      showTimePerChar: 30
      showAjaxErrors: true                  # catch global jQuery.ajaxErrors(), try detect message and show it
      showAjaxSuccesses: true               # catch global jQuery.ajaxSuccessess(), try detect message and show it
      detectFormErrors: true                # can be function (parsedJSON)
      detectPlainTextMaxLength: 200         # if response has plain text and its length fits, show it
      hideOnClick: true                     # click on notice fire hide()
      removeOnHide: true                    # remove notice DOM-element on hide
      forceAddDotsAfterLastWord: false
      forceRemoveDotsAfterLastWord: false
      regExpLastWordWithoutDot: /[\wа-яёА-ЯЁ]{3,}$/
      regExpLastWordWithDot: /([\wа-яёА-ЯЁ]{3,})\.$/

  @events:
    'click   .flash:not(:animated)' : 'closeFlashClick'

  constructor: (@jContainer, options = {}) ->
    super
    # init flashes from server
    @jFlashes().each (index, flash) =>
      jFlash = $ flash
      jFlash.html @_prepareText jFlash.html()
      @_setTimeout jFlash
    # binding hook ajaxError handler
    @jContainer.ajaxError =>
      @ajaxError arguments  if @settings.showAjaxErrors
    # binding hook ajaxSuccess handler
    @jContainer.ajaxSuccess =>
      @ajaxSuccess arguments  if @settings.showAjaxSuccesses

  # delegate event for hide on click
  closeFlashClick: (event) =>
    if @settings.hideOnClick
      @_hide $ event.currentTarget
      false

  jFlashes: (filterSelector) ->
    _jFlashes = @jContainer.find '.flash'
    if filterSelector then _jFlashes.filter filterSelector else _jFlashes

  _prepareText: (text) ->
    text = $.trim text
    # Add dot after last word (if word has minimum 3 characters)
    text += '.'  if @settings.forceAddDotsAfterLastWord and @settings.regExpLastWordWithoutDot.test text
    text = text.replace @settings.regExpLastWordWithDot, '$1'  if @settings.forceRemoveDotsAfterLastWord
    text

  _hide: (jFlash) ->
    clearTimeout jFlash.data 'timeoutId'
    _self = @
    jFlash.slideUp @settings.slideTime, -> $(@).remove()  if _self.settings.removeOnHide

  _setTimeout: (jFlash, timeout = @settings.showTime + jFlash.text().length * @settings.showTimePerChar) ->
    if timeout
      jFlash.data 'timeoutId', setTimeout =>
          jFlash.removeData 'timeoutId'
          @_hide jFlash
        , timeout

  show: (type, text) ->
    return false  if $.isEmptyString text
    jFlash = $ "<div class=\"flash #{type}\" style=\"display: none;\">#{@_prepareText text}</div>"
    jFlash.appendTo(@jContainer).slideDown @settings.slideTime
    @_setTimeout jFlash
    jFlash

  notice: (text) -> @show 'notice', text

  alert:  (text) -> @show 'alert',  text

  auto: (obj) ->
    if $.isArray obj
      @show a[0], a[1] for a in obj
    else if $.isPlainObject obj
      @show key, text for key, text of obj
    else false

  ###
   * @param  {Arguments} successArgs=[]   аргументы колбэка jQuery.success()
   * @return {Boolean}                    статус выполнения показа сообщения
  ###
  ajaxSuccess: (successArgs) ->
    # detect event as first element
    if successArgs[0].target
      # convert arguments to Array
      successArgs = args successArgs
      # remove event
      successArgs.shift()
    # arrange arguments
    if _.isString successArgs[0]
      # from jQuery.ajax().success()
      [data, _textStatus, jqXHR] = successArgs
    else
      # from jQuery.ajaxSuccess()
      [jqXHR, _ajaxSettings, data] = successArgs
    # prevent recall
    return false  if jqXHR.breakFlash
    jqXHR.breakFlash = true
    # detect notice
    if _.isString data
      # catch plain text message
      data = $.trim data
      return @notice data  if data.length <= @settings.detectPlainTextMaxLength and not $.isHTML data
    else if $.isPlainObject data
      # catch json data with flash-notice
      return @auto data['flash']  if data['flash']
    false

  ###
   * @param  {String}    [text="Ошибка"]   вступительный (либо полный) текст формируемой ошибки
   * @param  {Arguments} [errorArgs=[]]    аргументы колбэка jQuery.error()
   * @return {Boolean}                     статус выполнения показа сообщения
  ###
  ajaxError: ->
    text = @settings.translations.defaultErrorText
    errorArgs = []
    if arguments.length
      _next = arguments[0]
      if _.isString _next
        text = _next
        _next = arguments[1]  if arguments.length > 1
      errorArgs = _next  if not _.isString(_next) and _next.length
    if errorArgs.length
      errorArgs = args errorArgs
      errorArgs.shift()  if errorArgs[0].target # remove event
      [jqXHR, ajaxSettings, thrownError] = errorArgs
      # prevent undefined responses
      return false  if jqXHR.status < 100
      # prevent recall
      return false  if jqXHR.breakFlash
      jqXHR.breakFlash = true
      if jqXHR.responseText
        try
          # try parse respose as json
          if parsedJSON = $.parseJSON jqXHR.responseText
            # catch 'flash' object and call auto() method with autodetecting flash-notice type
            return @auto parsedJSON['flash']  if parsedJSON['flash']
            # catch 'error' object and call alert() method
            return @alert parsedJSON['error']  if parsedJSON['error']
            # may be parsedJSON is form errors
            if @settings.detectFormErrors is true
              # show message about form with errors
              return @alert @settings.translations.formFieldsError
            else if _.isFunction @settings.detectFormErrors
              # using showFormError as callback
              return @settings.detectFormErrors.apply @, [parsedJSON]
            else
              # nothing
              return false
        catch e
          # nop
      if jqXHR.status >= 400 and jqXHR.responseText
        # try detect Rails raise message
        if raiseMatches = jqXHR.responseText.match /<\/h1>\n<pre>(.+?)<\/pre>/
          @debug "replace thrownError = '#{thrownError}' with raiseMatches[1] = '#{raiseMatches[1]}'"
          thrownError = raiseMatches[1]
        else
          # try detect short text message as error
          if jqXHR.responseText.length <= @settings.detectPlainTextMaxLength
            @debug "replace thrownError = '#{thrownError}' with jqXHR.responseText = '#{jqXHR.responseText}'"
            thrownError = jqXHR.responseText
      else
        if _.isString thrownError and not $.isEmptyString thrownError
          @debug "replace thrownError = '#{thrownError}' with @settings.translations.defaultThrownError = '#{@settings.translations.defaultThrownError}'"
          thrownError = @settings.translations.defaultThrownError
      text += ': '  if text
      text += "#{thrownError} [#{jqXHR.status}]"
    return @alert text
