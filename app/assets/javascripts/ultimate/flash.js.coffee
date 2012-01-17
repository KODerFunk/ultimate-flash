###
 * Ultimate Flash 0.4.7.alpha - Ruby on Rails oriented jQuery plugin
 *
 * Copyright 2011-2012 Karpunin Dmitry (KODer) / Evrone.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
###

# TODO architecture of wiggets in ultimate/widgets.js.coffee
# TODO customizable show() and hide()
# TODO improve English

class UltimateFlashWidget

  @defaults:
    constants:
      widgetDataKey: 'ultimate_flash'
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
      locale: 'en'

  jContainer: null
  settings: {}

  constructor: (@jContainer, options = {}) ->
    if I18n? and I18n.locale and I18n.t
      options['locale'] ||= I18n.locale
      if _localesFromI18n = I18n.t 'ultimate_flash'
        _defaultLocales = @constructor.defaults.locales[I18n.locale]
        for key, value of _localesFromI18n
          _defaultLocales[_.camelize key] = value
    _locale = options['locale'] or @constructor.defaults.options['locale']
    $.error "Locale [#{_locale}] not exists in UltimateFlash default locales."  unless @constructor.defaults.locales[_locale]
    @settings = $.extend {}, @constructor.defaults.options, @constructor.defaults.locales[_locale], options
    @jContainer.data @constructor.defaults.constants.widgetDataKey, @
    _self = @
    # delegate event for hide on click
    @jContainer.delegate '.flash:not(:animated)', 'click.ultimate_flash_close', ->
      _self._hide $ @  if _self.settings.hideOnClick
      false
    # init flashes from server
    @jFlashes().each ->
      jFlash = $ @
      jFlash.html _self._prepareText jFlash.html()
      _self._setTimeout jFlash
    # binding hook ajaxError handler
    @jContainer.ajaxError =>
      @ajaxError arguments  if @settings.showAjaxErrors
    # binding hook ajaxSuccess handler
    @jContainer.ajaxSuccess =>
      @ajaxSuccess arguments  if @settings.showAjaxSuccesses

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
    clearTimeout jFlash.data 'timeout_id'
    _self = @
    jFlash.slideUp @settings.slideTime, -> $(@).remove()  if _self.settings.removeOnHide

  _setTimeout: (jFlash) ->
    timeoutId = false
    if @settings.showTime or @settings.showTimePerChar
      timeoutId = setTimeout =>
          @_hide jFlash
        , @settings.showTime + jFlash.text().length * @settings.showTimePerChar
      jFlash.data 'timeout_id', timeoutId
    timeoutId

  getSettings: ->
    @settings

  setSettings: (settings) ->
    @settings = settings

  updateSettings: (options) ->
    $.extend @settings, (if options['locale'] then @constructor.defaults.locales[options['locale']] else {}), options
    @settings

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
    if $.isString successArgs[0]
      # from jQuery.ajax().success()
      [data, _textStatus, jqXHR] = successArgs
    else
      #from. jQuery.ajaxSuccess()
      [jqXHR, _ajaxSettings, data] = successArgs
    # prevent recall
    return false  if jqXHR.breakFlash
    jqXHR.breakFlash = true
    # detect notice
    if $.isString data
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
    text = @settings.defaultErrorText
    errorArgs = []
    if arguments.length
      _next = arguments[0]
      if $.isString _next
        text = _next
        _next = arguments[1]  if arguments.length > 1
      errorArgs = _next  if not $.isString(_next) and _next.length
    if errorArgs.length
      errorArgs = args errorArgs
      errorArgs.shift()  if errorArgs[0].target # remove event
      [jqXHR, ajaxSettings, thrownError] = errorArgs
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
              return @alert @settings.formFieldsError
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
          thrownError = raiseMatches[1]
        else
          # get short text message as error
          thrownError = jqXHR.responseText  if jqXHR.responseText.length <= @settings.detectPlainTextMaxLength
      else
        thrownError = @settings.defaultThrownError  if $.isString thrownError and not $.isEmptyString thrownError
      text += ': '  if text
      text += "#{thrownError} [#{jqXHR.status}]"
    return @alert text



( ($) ->

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
   * ajaxError       .ultimateFlash('ajaxError'[, String text = settings.defaultErrorText][, Arguments errorArgs = []])
  ###
  $.fn.ultimateFlash = ->
    return @  unless @length
    jContainer = @eq 0
    widget = jContainer.data UltimateFlashWidget.defaults.constants.widgetDataKey
    argsLength = arguments.length
    _returnWidget = argsLength && arguments[argsLength - 1] == true
    if widget and widget.jContainer[0] == jContainer[0]
      a = args arguments
      if argsLength and typeof a[0] == 'string'
        command = a.shift()
      else
        return widget  if _returnWidget
        return jContainer  unless argsLength
        command = 'updateSettings'
      if $.isFunction widget[command]
        return widget[command].apply widget, a
      else
        $.error "Command [#{command}] does not exist on jQuery.ultimateFlash()"
    else
      options = if argsLength then arguments[0] else {}
      widget = new UltimateFlashWidget jContainer, options
      jContainer.data UltimateFlashWidget.defaults.constants.widgetDataKey, widget
    if _returnWidget then widget else jContainer

)( jQuery )
