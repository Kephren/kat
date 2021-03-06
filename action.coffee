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
    message = "Applying '#{func}' within Casper."
    @echo message
    func.apply @, ([courier, @]).concat(args)
    courier.response(message, true, action)

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
    message = "Capturing '#{fullName}'."
    @echo message
    @captureSelector fullName, selector
    @wait(500)
    courier.response(message, true, action)

clearCookies = (action, courier, casper) ->
  casper.then ->
    message = "Clearing browser cache."
    @echo message
    phantom.clearCookies()
    @wait(500)
    courier.response(message, true, action)

createCookie = (action, courier, casper) ->
  cookie = getOrElse(action, "cookie", {})
  casper.then ->
    defaults = {
      value: true,
      path: "/",
      httponly: false,
      secure: false,
      expires: (new Date()).getTime() + (1000 * 60 * 60)
    }
    cookieWithDefaults = _.defaults(cookie, defaults)
    message = "Added browser cookie for #{cookieWithDefaults.name}."
    @echo message
    phantom.addCookie(cookieWithDefaults)
    courier.response(message, true, action)

clickElement = (action, courier, casper)->
  selector = getOrElse(action, "select")
  casper.then ->
    selector = interpolate(courier, selector)
    message = "Clicking on \<#{selector}\>."
    @echo message
    @click selector
    @wait(1000)
    courier.response(message, true, action)


clickText = (action, courier, casper)->
  text = getOrElse(action, "text")
  casper.then ->
    text = interpolate(courier, text)
    message = "Clicking on text '#{text}'."
    @echo message
    @clickLabel text
    @wait(1000)
    courier.response(message, true, action)

downloadFile = (action, courier, casper)->
  url = getOrElse(action, "url")
  path = getOrElse(action, "path")
  casper.then ->
    url = interpolate(courier, url)
    path = interpolate(courier, path)
    message = "Downloading from url \/#{url}\/ to '#{path}'."
    @echo message
    @page.settings.webSecurityEnabled = false;
    @download url, path
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
    message = "Evaluating -> #{func}"
    @echo message
    func = eval("[#{func}]")
    courier.response(message, true, action)
    evaluated = @evaluate.apply @, func.concat(args)
    message = "Storing '#{key}':'#{evaluated}' from evaluating -> #{func}."
    @echo message
    courier.store(key, evaluated)
    courier.response(message, true, action)


fillElement = (action, courier, casper) ->
  form = getOrElse(action, "form")
  map = getOrElse(action, "map")
  submit = getOrElse(action, "submit", "yes") is "yes"
  casper.then ->
    fill = {}
    if _.isObject map
      message = []
      i = 0
      l = _.size map
      interpolatedMap = _.cloneDeep(map)
      _.each interpolatedMap, (value, selector, obj) ->
        obj[selector] = interpolate(courier, value) #check for data set information
      _.extend fill, interpolatedMap
      _.each fill, (value, selector) ->
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
      @echo message
    else
      @echo message
      @wait 1000
      @fillSelectors form, fill, submit
      @wait 1000
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
    message = "Opening link to \<#{url}\>."
    @echo message
    @wait(500)
    @open url
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
        truncatedResult = if evaluated.length < 50 then evaluated else "#{evaluated.substring(0,50)}..."
        message = "Storing attribute '#{attribute} into '#{key}':'#{truncatedResult}' from \<#{selector}\>."
        @echo message
        courier.store(key, evaluated)
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
    message = "Typing '#{text}' in \<#{selector}\>."
    @echo message
    @wait(500)
    @click selector
    @wait(500)
    @sendKeys selector, text, {"reset": true, "modifiers": modifiers}
    @wait(1000)
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
    courier.response(message, true, action)
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
    when "clear" then clearCookies(action, courier, casper)
    when "click" then clickElement(action, courier, casper)
    when "clickText" then clickText(action, courier, casper)
    when "cookie" then createCookie(action, courier, casper)
    when "disabled" then waitForDisabled(action, courier, casper)
    when "download" then downloadFile(action, courier, casper)
    when "echo" then echoMessage(action, courier, casper)
    when "enabled" then waitForEnabled(action, courier, casper)
    when "find" then waitForSelector(action, courier, casper)
    when "fill" then fillElement(action, courier, casper)
    when "open" then openLink(action, courier, casper)
    when "run" then evaluateFunction(action, courier, casper)
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
    clear: (action, perform) ->
      {
        "action": action,
        "perform": perform
      }
    clickText: (action, text) ->
      {
        "action": action,
        "text": text
      }
    click: (action, select) ->
      {
        "action": action
        "select": select
      }
    cookie: (action, map) ->
      {
        "action": action,
        "cookie": map
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
    fill: (action, form, map, submit) ->
      {
        "action": action
        "form": form
        "map": map,
        "submit": submit
      }
    find: (action, select, timeout) ->
      {
        "action": action
        "select": select
        "timeout": timeout
      }
    get: (action, select, attribute, key) ->
      {
        "action": action
        "select": select
        "attribute": attribute
        "key": key
      }
    open: (action, url, user, password) ->
      {
        "action": action
        "url": url
        "user": user
        "password": password
      }
    run: (action, func, args, key) ->
      {
        "action": action
        "func": func
        "args": args
        "key": key
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
exports.step = (action, courier, casper) ->
  name = getOrElse(action, "action", false)
  if name then fireAction(name, action, courier, casper)
  else shortHandMapper(action, courier, casper)
exports.test = -> "Actions module loaded successfully."
