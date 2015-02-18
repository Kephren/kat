yaml = require("./lib/yaml")
_ = require "./lib/lodash.min"

getDelimiterByExtension = (type) ->
  switch type
    when "tsv", "tab" then "\t"
    when "csv", "comma" then ","
    when "spc", "space" then " "
    else ","

# Module
exports.courier = ->
  _result = {
    "_responses": []
    "_store": {}
    "_sets": []
    "_entry": 1
  }
  return {
    index: -> _result._responses.length
    response: (message, success, step)->
      entry = {
        "id": _result._responses.length,
        "set": _result._sets.length
        "entry": _result._entry
        "message": message.replace(///\n///g, ", "),
        "success": success,
        "timestamp": (new Date()).toISOString()
      }
      if step isnt undefined then _.extend entry, { "step": step }
      _result._responses.push entry
      _result._entry++
    store: (key, value) ->
      if value is undefined then _result._store[key] else _result._store[key] = value
    pushSet: (entry) ->
      if _.isObject(entry)
        _result._sets.push entry
        _result._store = _.defaults(entry, _result._store)
        _result._entry = 1
    dump: -> { "responses": _result._responses, "sets": _result._sets  }
  }

exports.parse = (type, raw, eol) ->
  switch type
    when "tab", "comma", "space" # Top row header.
      eol = eol || "\n"
      lines = raw.trim().split eol
      delimiter = getDelimiterByExtension(type)
      targetArray = []
      headers = lines[0].split delimiter
      rows = _.tail lines
      _.forEach rows, (row) ->
        r = row.split delimiter
        _.each r, (i) ->i.toString()
        targetArray.push _.zipObject(headers, r)
      targetArray
    when "tsv", "csv", "spc"  # Leftmost column header.
      eol = eol || "\n"
      lines = raw.trim().split eol
      delimiter = getDelimiterByExtension(type)
      targetArray = []
      headers = []
      rows = _.clone lines
      lengths = _.map rows, (row) ->
        r = row.split delimiter
        headers.push r[0]
        r.length
      max = _.max lengths
      min = _.min lengths
      if min isnt max then console.error "warning: data set is uneven."
      width = max - 1
      for c in [1..width] by 1
        rows = _.clone lines
        values = []
        _.each rows, (row) ->
          r = row.split delimiter
          if r.length > c then values.push(r[c]) else values.push ""
        _.reject headers, (e) -> _.isEmpty(e)
        _.reject values, (e) -> _.isEmpty(e)
        targetArray.push _.zipObject(headers, values)
      console.log "Set Count: #{targetArray.length}"
      targetArray
    when "json", "js" then return JSON.parse(raw) || null
    when "yml", "yaml" then return yaml.eval(raw) || null
    else
      console.error "warning: data set was not parsed."
      raw