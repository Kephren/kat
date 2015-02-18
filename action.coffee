_ = require "./lib/lodash.min"
DEFAULT_TIMEOUT = 5000

interpolate = (courier, value) ->
  # TODO: make this a loop to allow for multiple variables
  re = RegExp("^\\${([^}]*)}$")
  if _.isString(value) && re.test(value)
    key = value.replace(///(^\$\{|\}$)///g, "")
  courier.store(key) || value

getOrElse = (object, key, fallback) ->  _.result(object, key) || fallback

xPathToCss = (xpath) ->
  # This is a very basic mapper.
  # XPath has a more extensive selector syntax
  # and cannot be equally represented by CSS
  if xpath
    xpath.replace(///[(\d+?)]///g, (s, m1) ->
      '[' + (m1 - 1) + ']')
    .replace(////{2}///g, '')
    .replace(////+///g, ' > ')
    .replace(///@///g, '')
    .replace(///[(\d+)]///g, ':eq($1)')
    .replace(///^\s+///, '')
  else false

casperFunction = (action, courier, casper) ->
  func = getOrElse(action, "func", "function() {}" )
  args = getOrElse(action, "args", [])
  casper.then ->
    func = interpolate(courier, func)
    args = _.map(args, (s) -> interpolate(courier, s))
    func = eval("[#{func}][0]")
    @echo "Applying '#{func}' within Casper."
    func.apply @, ([courier, @]).concat(args)

captureScreenShot = (action, courier, casper)->
  selector = getOrElse(action, "select", "body")
  view = getOrElse(action, "viewport", false)
  if view then casper.viewport(view.width, view.height)
  else
    width = getOrElse(action, "width", false)
    height = getOrElse(action, "height", false)
    if width && height then casper.viewport(width, height)
  ssPath = getOrElse(action, "screenshots", "./data/screenshots")
  casper.then ->
    selector = interpolate(courier, selector)
    @wait(2500)
    #"20140121T152846.493Z" ISO8601 * RFC 3339 Compliant,
    # just need to use local time offset modifier
    timestamp = new Date()
    ts = timestamp.toISOString().replace(///[\:]///g, "")
    ssp = "#{ssPath}/".replace(////+$///g, "/")
    name = courier.store("name") || "Test"
    fullName = "#{ssp}#{name}-#{ts}.png"
    @captureSelector fullName, selector
    @wait(500)
    message = "Captured '#{fullName}.'"
    @echo message
    courier.response(message, true, action)

clickElement = (action, courier, casper)->
  selector = getOrElse(action, "select")
  casper.then ->
    selector = interpolate(courier, selector)
    @click selector
    message = "Clicked on \<#{selector}\>."
    @echo message
    courier.response(message, true, action)
    @wait(1000)

downloadFile = (action, courier, casper)->
  url = getOrElse(action, "url")
  path = getOrElse(action, "path")
  casper.then ->

    url = interpolate(courier, url)
    path = interpolate(courier, path)
    message = "Downloading from url \/#{url}\/> to '#{path}'."
    @page.settings.webSecurityEnabled = false;
    @download url, path
    @echo message
    courier.response(message, true, action)

echoMessage = (action, courier, casper)->
  message = getOrElse(action, "message")
  casper.then ->
    message = interpolate(courier, message)
    @echo message
    courier.response(message, true, action)

evaluateFunction = (action, courier, casper) ->
  key = getOrElse(action, "key")
  func = getOrElse(action, "func", "function() {}" )
  args = getOrElse(action, "args", [])
  casper.then ->
    key = interpolate(courier, key)
    func = interpolate(courier, func)
    args = _.map(args, (s) -> interpolate(courier, s))
    func = eval("[#{func}]")
    evaluated = @evaluate.apply @, func.concat(args)
    courier.store(key, evaluated)
    @echo "Stored '#{key}':'#{evaluated}' from evaluating -> #{func}."

fillElement = (action, courier, casper) ->
  form = getOrElse(action, "form")
  map = getOrElse(action, "map")
  submit = getOrElse(action, "submit", "no") is "yes"
  casper.then ->
    fill = {}
    if _.isObject map
      message = []
      i = 0
      l = _.size map
      _.each map, (value, selector, obj) ->
        obj[selector] = interpolate(courier, value) #check for data set information
      _.extend fill, map
      _.each map, (value, selector) ->
        i++;
        message.push "Form field #{i} of #{l} filled \<#{selector}\> with '#{value}'"
      message = message.join("\n") + "."
    else
      selector = getOrElse(action, "select")
      value = getOrElse(action, "value")
      fill["#{selector}"] = interpolate(courier, value)
      message = "Form field filled \<#{selector}\> with '#{value}'."
    if form is false or !_.isObject(fill)
      message = "Invalid data entry for form or fill values."
    else
      @wait 1000
      @fillSelectors form, fill, submit
      @wait 1000
    @echo message
    courier.response(message, true, action)

openLink = (action, courier, casper) ->
  url = getOrElse(action, "url")
  casper.options.waitTimeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  user = getOrElse(action, "user", false)
  password = getOrElse(action, "password", false)
  casper.then ->
    @wait(500)
    user = interpolate(courier, user)
    password = interpolate(courier, password)
    if user and password
      casper.setHttpAuth(user, password)
      @echo "Logging in with '#{user}'."
    url = interpolate(courier, url)
    @wait(500)
    @open url
    message = "Opening link to \<#{url}\>."
    @echo message
    courier.response(message, true, action)

setAttribute = (action, courier, casper) ->
  selector = getOrElse(action, "select")
  attribute = getOrElse(action, "attribute")
  value = getOrElse(action, "value")
  casper.then ->
    selector = interpolate(courier, selector)
    attribute = interpolate(courier, attribute)
    value = interpolate(courier, value)
    if @.exists(selector)
      evaluated = @evaluate (selector, attribute, value) ->
          if attribute is "html()"
            $(selector).html(value)
            return $(selector).html() == value
          else if attribute is "val()"
            $(selector).val(value)
            return $(selector).val() == value
          else
            $(selector).attr(attribute, value)
            return $(selector).attr(attribute) == value
          return false
        , selector, attribute, value
      if evaluated is true
        message = "Set \<#{selector}\> attribute '#{attribute}' to '#{value}'"
        @echo message
        courier.response(message, true, action)
      else
        message = "Failed to set \<#{selector}\> attribute '#{attribute}' to '#{value}'"
        @echo message
        courier.response(message, false, action)
    else
      message = "Failed to set \<#{selector}\> attribute '#{attribute}' to '#{value}'"
      @echo message
      courier.response(message, false, action)

getAttribute = (action, courier, casper) ->
  key = getOrElse(action, "key")
  selector = getOrElse(action, "select")
  attribute = getOrElse(action, "attribute", "value")
  casper.then ->
    key = interpolate(courier, key)
    selector = interpolate(courier, selector)
    attribute = interpolate(courier, attribute)
    failed = "Failed to get attribute '#{attribute}' from \<#{selector}\>"
    if @.exists(selector)
      evaluated = @evaluate (selector, attribute) ->
        if attribute is "html()"
          return $(selector).html()
        else if attribute is "val()"
          return $(selector).val()
        else
          return $(selector).attr(attribute)
        failed
      , selector, attribute
      if evaluated isnt failed
        courier.store(key, evaluated)
        message = "Stored attribute '#{attribute} into '#{key}':'#{evaluated}' from \<#{selector}\>."
        @echo message
        courier.response(message, true, action)
      else
        @echo failed
        courier.response(failed, false, action)
    else
      @echo failed
    courier.response(failed, false, action)

typeKeys = (action, courier, casper) ->
  selector = getOrElse(action, "select")
  modifiers = getOrElse(action, "modifiers")
  text = getOrElse(action, "text")
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    selector = interpolate(courier, selector)
    text = interpolate(courier, text)
    @wait(500)
    @click selector
    @wait(500)
    @sendKeys selector, text, {"reset": true, "modifiers": modifiers}
    @wait(1000)
    message = "Typing '#{text}' in \<#{selector}\>."
    @echo message
    courier.response(message, true, action)

waitForEnabled = (action, courier, casper) ->
  selector = getOrElse(action, "select")
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    selector = interpolate(courier, selector)
    @echo "Waiting for element \<#{selector}\>"
    @waitFor ->
      info = @getElementsInfo(selector)
      disabled = _.filter(info, "disabled")
      disabled.length == 0
    , ->
      message = "Elements \<#{selector}\> are all enabled."
      @echo message
      courier.response(message, true, action)
    , ->
      message = "Elements \<#{selector}\> are not enabled."
      @echo message
      courier.response(message, false, action)
    , timeout

waitForDisabled = (action, courier, casper) ->
  selector = getOrElse(action, "select")
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    selector = interpolate(courier, selector)
    @echo "Waiting for element \<#{selector}\>"
    @waitFor ->
      info = @getElementsInfo(selector)
      disabled = _.filter(info, "disabled")
      disabled.length == info.length
    , ->
      message = "Elements \<#{selector}\> are all disabled."
      @echo message
      courier.response(message, true, action)
    , ->
      message = "Elements \<#{selector}\> are not disabled."
      @echo message
      courier.response(message, false, action)
    , timeout

waitForSelector = (action, courier, casper) ->
  selector = getOrElse(action, "select")
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    selector = interpolate(courier, selector)
    @echo "Waiting for element \<#{selector}\>"
    @waitForSelector selector, ->
      message = "Found \<#{selector}\>."
      @echo message
      courier.response(message, true, action)
    , ->
      message = "Failed to find \<#{selector}\>."
      @echo message
      courier.response(message, false, action)
    , timeout

waitForText = (action, courier, casper) ->
  text = getOrElse(action, "text")
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    text = interpolate(courier, text)
    @echo "Waiting for text '#{text}'"
    @waitForText text, -> #result
      message = "Found '#{text}'."
      @echo message
      courier.response(message, true, action)
    , ->
      message = "Failed to find '#{text}'."
      @echo message
      courier.response(message, false, action)
    , timeout

waitForTimeout = (action, courier, casper) ->
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    message = "Waiting for #{(timeout / 1000).toFixed(2)} second(s)."
    @echo message
    courier.response(null, message, true, action)
    @wait timeout

waitForUrl = (action, courier, casper) ->
  pattern = getOrElse(action, "pattern", "")
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    pattern = interpolate(courier, pattern)
    @echo "Waiting for url \/#{pattern}\/>"
    @waitForUrl new RegExp(pattern), -> #result
      message = "Loaded \/#{pattern}\/."
      @echo message
      courier.response(message, true, action)
    , ->
      message = "Failed to load \/#{pattern}\/."
      @echo message
      courier.response(message, false, action)
    , timeout

waitForVisibility = (action, courier, casper)->
  selector = getOrElse(action, "select")
  timeout = getOrElse(action, "timeout", DEFAULT_TIMEOUT)
  casper.then ->
    selector = interpolate(courier, selector)
    @echo "Waiting to see \<#{selector}\>"
    @waitUntilVisible selector, ->
      message = "Saw \<#{selector}\>."
      @echo message
      courier.response(message, true, action)
    , ->
      message = "Failed to see \<#{selector}\>."
      @echo message
      courier.response(message, false, action)
    , timeout

fireAction = (name, action, courier, casper) ->
  switch name
    when "capture" then captureScreenShot(action, courier, casper)
    when "casper" then casperFunction(action, courier, casper)
    when "click" then clickElement(action, courier, casper)
    when "disabled" then waitForDisabled(action, courier, casper)
    when "download" then downloadFile(action, courier, casper)
    when "echo" then echoMessage(action, courier, casper)
    when "enabled" then waitForEnabled(action, courier, casper)
    when "run" then evaluateFunction(action, courier, casper)
    when "find" then waitForSelector(action, courier, casper)
    when "fill" then fillElement(action, courier, casper)
    when "open" then openLink(action, courier, casper)
    when "set" then setAttribute(action, courier, casper)
    when "get" then getAttribute(action, courier, casper)
    when "text" then waitForText(action, courier, casper)
    when "type" then typeKeys(action, courier, casper)
    when "uri" then waitForUrl(action, courier, casper)
    when "visible" then waitForVisibility(action, courier, casper)
    when "wait" then waitForTimeout(action, courier, casper)
    else
      console.error "Step #{courier.index()}: #{name} is not an available action."

shortHandMapper = (action, courier, casper) ->
  shortHand = {
    capture: (action, select, name, height, width) ->
      {
        "action": action
        "select": select
        "name": name
        "height": height
        "width": width
      }
    casper: (action, func, args) ->
      {
        "action": action
        "func": func
        "args": args
      }
    click: (action, select) ->
      {
        "action": action
        "select": select
      }
    disabled: (action, select, timeout) ->
      {
        "action": action
        "select": select
        "timeout": timeout
      }
    download: (action, url, path, timeout) ->
      {
        "action": action
        "url": url
        "path": path
        "timeout": timeout
      }
    echo: (action, message) ->
      {
        "action": action
        "message": message
      }
    enabled: (action, select, timeout) ->
      {
        "action": action
        "select": select
        "timeout": timeout
      }
    fill: (action, form, map) ->
      {
        "action": action
        "form": form
        "map": map
      }
    find: (action, select, timeout) ->
      {
        "action": action
        "select": select
        "timeout": timeout
      }
    get: (action, key, select, attribute) ->
      {
        "action": action
        "key": key
        "select": select
        "attribute": attribute
      }
    open: (action, url, user, password) ->
      {
        "action": action
        "url": url
        "user": user
        "password": password
      }
    run: (action, key, func, args) ->
      {
        "action": action
        "key": key
        "func": func
        "args": args
      }
    set: (action, select, attribute, value) ->
      {
        "action": action
        "select": select
        "attribute": attribute
        "value": value
      }
    text: (action, text, timeout) ->
      {
        "action": action
        "text": text
        "timeout": timeout
      }
    type: (action, select, text, modifiers) ->
      {
        "action": action
        "select": select
        "text": text
        "modifiers": modifiers
      }
    uri: (action, pattern, timeout) ->
      {
        "action": action
        "pattern": pattern
        "timeout": timeout
      }
    visible: (action, select, timeout) ->
      {
        "action": action
        "select": select
        "timeout": timeout
      }
    wait: (action, timeout) ->
      {
        "action": action
        "timeout": timeout
      }
  }
  _.forEach action, (v, k) ->
    if shortHand.hasOwnProperty(k)
      mapped = if _.isString v then shortHand[k].apply @, [k].concat([v]) else shortHand[k].apply @, [k].concat(v)
      exports.step(mapped, courier, casper)
    else
      console.error "warning: shorthand '#{k}' action not available."

# Module
exports.test = ->
  console.log "Actions module test successful."
exports.step = (action, courier, casper) ->
  name = getOrElse(action, "action", false)
  if name then fireAction(name, action, courier, casper)
  else shortHandMapper(action, courier, casper)