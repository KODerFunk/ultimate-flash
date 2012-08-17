###*
 * Ultimate Flash 0.6.0 - Ruby on Rails oriented jQuery plugin based on Ultimate Backbone
 *
 * Copyright 2011-2012 Karpunin Dmitry (KODer) / Evrone.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
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
 *     get options     .pluginName("options")                                 : {Object} view options
 *     show            .ultimateFlash("show", String type, String text)       : {jQuery} jFlash | {Boolean} false
 *     notice          .ultimateFlash("notice", String text)                  : {jQuery} jFlash | {Boolean} false
 *     alert           .ultimateFlash("alert", String text)                   : {jQuery} jFlash | {Boolean} false
 *   extended actions:
 *     auto            .ultimateFlash("auto", {ArrayOrObject} obj)            : {Array} ajFlashes | {Boolean} false
 *     ajaxSuccess     .ultimateFlash("ajaxSuccess"[, Arguments successArgs = []])
 *     ajaxError       .ultimateFlash("ajaxError"[, String text = translations.defaultErrorText][, Arguments errorArgs = []])
###

# TODO customizable show() and hide()
# TODO improve English
# TODO jGrowl features

#= require ultimate/backbone/view
#= require ultimate/backbone/extra/jquery-plugin-adapter

Ultimate.Backbone.Plugins ||= {}

class Ultimate.Backbone.Plugins.Flash extends Ultimate.Backbone.View

  el: ".l-page__flashes"

  @defaultLocales:
    en:
      defaultErrorText: "Error"
      defaultThrownError: "server connection error"
      formFieldsError: "Form filled with errors"
    ru:
      defaultErrorText: "Ошибка"
      defaultThrownError: "ошибка соединения с сервером"
      formFieldsError: "Форма заполнена с ошибками"

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

  events:
    "click   .flash:not(:animated)" : "closeFlashClick"

  initialize: (options) ->
    super
    # init flashes come from server in page
    @jFlashes().each (index, flash) =>
      jFlash = $(flash)
      jFlash.html @_prepareText(jFlash.html())
      @_setTimeout jFlash
    # binding hook ajaxError handler
    @$el.ajaxError =>
      if @showAjaxErrors
        a = @_ajaxSuccessParseArguments(arguments)
        Ultimate.Backbone.debug ".Plugins.Flash.ajaxError", a
        @ajaxError a.data, a.jqXHR
    # binding hook ajaxSuccess handler
    @$el.ajaxSuccess =>
      if @showAjaxSuccesses
        a = @_ajaxSuccessParseArguments(arguments)
        Ultimate.Backbone.debug ".Plugins.Flash.ajaxSuccess", a
        @ajaxSuccess a.data, a.jqXHR

  # delegate event for hide on click
  closeFlashClick: (event) ->
    if @hideOnClick
      @_hide $(event.currentTarget)
      false

  jFlashes: (filterSelector) ->
    _jFlashes = @$(".flash")
    if filterSelector then _jFlashes.filter(filterSelector) else _jFlashes

  _prepareText: (text) ->
    text = _.clean(text)
    # Add dot after last word (if word has minimum 3 characters)
    text += "."  if @forceAddDotsAfterLastWord and @regExpLastWordWithoutDot.test(text)
    text = text.replace(@regExpLastWordWithDot, "$1")  if @forceRemoveDotsAfterLastWord
    text

  _hide: (jFlash) ->
    clearTimeout jFlash.data("timeoutId")
    jFlash.slideUp @slideTime, =>
      jFlash.remove()  if @removeOnHide

  _setTimeout: (jFlash, timeout = @showTime + jFlash.text().length * @showTimePerChar) ->
    if timeout
      jFlash.data "timeoutId", setTimeout =>
          jFlash.removeData("timeoutId")
          @_hide jFlash
        , timeout

  show: (type, text, timeout = null) ->
    return false  if not _.isString(text) or _.isBlank(text)
    jFlash = $("<div class=\"flash #{type}\" style=\"display: none;\">#{@_prepareText(text)}</div>")
    jFlash.appendTo(@$el).slideDown @slideTime
    @_setTimeout jFlash, timeout
    jFlash

  notice: (text, timeout = null) -> @show "notice", text, timeout

  alert:  (text, timeout = null) -> @show "alert",  text, timeout

  auto: (obj) ->
    if _.isArray(obj)
      @show(pair[0], pair[1])  for pair in obj
    else if _.isObject(obj)
      @show(key, text)  for key, text of obj
    else false

  ###*
   * @param  {Arguments} successArgs=[]   аргументы колбэка jQuery.success()
   * @return {data: data, jqXHR: jqXHR}
  ###
  _ajaxSuccessParseArguments: (successArgs) ->
    # detect event as first element
    if successArgs[0] instanceof jQuery.Event
      # convert arguments to Array
      successArgs = args(successArgs)
      # remove event
      successArgs.shift()
    # arrange arguments
    if _.isString(successArgs[0])
      # from jQuery.ajax().success()
      [data, _textStatus, jqXHR] = successArgs
    else
      # from jQuery.ajaxSuccess() or jQuery.ajaxError()
      [jqXHR, _ajaxSettings, data] = successArgs
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
      data = _.trim(data)
      return @notice(data)  if data.length <= @detectPlainTextMaxLength and not $.isHTML(data)
    else if _.isObject(data)
      # catch json data with flash-notice
      return @auto(data["flash"])  if data["flash"]
    false

  ###*
   * @param  {String}    [text="Ошибка"]   вступительный (либо полный) текст формируемой ошибки
   * @param  {String}     thrownError      some error from ajax response
   * @param  {jqXHR}      jqXHR            jQuery XHR
   * @return {Boolean}                     статус выполнения показа сообщения
  ###
  ajaxError: (text, thrownError, jqXHR) ->
    unless _.isObject(jqXHR)
      jqXHR = thrownError
      thrownError = text
      text = @translations.defaultErrorText
    # prevent undefined responses
    return false  if jqXHR.status < 100
    # prevent recall
    return false  if jqXHR.breakFlash
    jqXHR.breakFlash = true
    if jqXHR.responseText
      try
        # try parse respose as json
        if parsedJSON = $.parseJSON(jqXHR.responseText)
          # catch "flash" object and call auto() method with autodetecting flash-notice type
          return @auto(parsedJSON["flash"])  if parsedJSON["flash"]
          # catch "error" object and call alert() method
          return @alert(parsedJSON["error"])  if parsedJSON["error"]
          # may be parsedJSON is form errors
          if @detectFormErrors is true
            # show message about form with errors
            return @alert(@translations.formFieldsError)
          else if _.isFunction(@detectFormErrors)
            # using showFormError as callback
            return @detectFormErrors.apply(@, [parsedJSON])
          else
            # nothing
            return false
      catch e
        # nop
    if jqXHR.status >= 400 and jqXHR.responseText
      # try detect Rails raise message
      if raiseMatches = jqXHR.responseText.match(/<\/h1>\n<pre>(.+?)<\/pre>/)
        Ultimate.Backbone.debug "replace thrownError = \"#{thrownError}\" with raiseMatches[1] = \"#{raiseMatches[1]}\""
        thrownError = raiseMatches[1]
      else
        # try detect short text message as error
        if jqXHR.responseText.length <= @detectPlainTextMaxLength
          Ultimate.Backbone.debug "replace thrownError = \"#{thrownError}\" with jqXHR.responseText = \"#{jqXHR.responseText}\""
          thrownError = jqXHR.responseText
    else
      if _.isString(thrownError) and not _.isBlank(thrownError)
        Ultimate.Backbone.debug "replace thrownError = \"#{thrownError}\" with @translations.defaultThrownError = \"#{@translations.defaultThrownError}\""
        thrownError = @translations.defaultThrownError
    text += ": "  if text
    text += "#{thrownError} [#{jqXHR.status}]"
    return @alert(text)



Ultimate.Backbone.createJQueryPlugin "ultimateFlash", Ultimate.Backbone.Plugins.Flash
