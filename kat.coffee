###
  Kat - Casper's best friend.
    JSON/YAML Scripting for CasperJS

  The BSD License (BSD)

  Copyright (c) 2014 Kephren Newton <kephren.newton@gmail.com>

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
  * Neither the name of the <organization> nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT+
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###

console.log "Starting Kat"
console.log ""

# Loading Libraries
fs = require "fs"
system = require "system"
utils = require "utils"
actions = require "./action"
utilities = require "./utilities"
courier = utilities.courier()
parse = utilities.parse
casper = require("casper").create({ clientScripts: ["lib/jquery.min.js", "lib/lodash.min.js"] }) #{ verbose: true, logLevel: 'debug'})
_ = require "./lib/lodash.min"

console.info("utilities: #{utilities.test()}")
console.info("actions: #{actions.test()}")
console.info("courier: #{courier.test()}")

debugger

# Load template and set path arguments
templatePath = casper.cli.get("template") || "./data/templates/test-template.json"
setPath = casper.cli.get("set") || "./data/sets/test-set.json"
logPath = casper.cli.get("logs") || "./data/logs/"
ssPath = casper.cli.get("screenshots") || "./data/screenshots/"

if casper.cli.get("template") then console.log " --template=#{templatePath}"
if casper.cli.get("set") then console.log " --set=#{setPath}"
if casper.cli.get("logs") then console.log " --logs=#{logPath}"
if casper.cli.get("screenshots") then console.log " --screenshots=#{ssPath}"



# Cleanup functions
tail = (path) -> (/\.([0-9a-z]+)$/i.exec(path) )[1]
getOrElse = (object, key, fallback) -> _.result(object, key) || fallback

# Cleanup file paths and load data
eol = if system.os.name is 'windows' then "\r\n" else "\n"
# Cleanup tailing forward slashes
lp = "#{logPath}/".replace(////+$///g, "/")
ss = "#{ssPath}/".replace(////+$///g, "/")

template = {}
setData = {}
if templatePath
  templateType = tail templatePath
  templateRaw = fs.read(templatePath)
  template = parse(templateType, templateRaw, eol)
if setPath
  setType = tail setPath
  setRaw = fs.read(setPath)
  console.log "Loading Data Set."
  setData = parse(setType, setRaw, eol)

if _.isEmpty(template) is false # Data was loaded, proceed...

  # Display paths to be used during run-time.
  if templatePath then console.log "Template File: #{templatePath}"
  if lp then console.log "Log Path: #{lp}"
  if setPath then console.log "Set File: #{setPath}"
  if ss then console.log "Screenshot Path: #{ss}"

  # Setup directory defaults inside template if not present
  if !getOrElse(template, "logs", false) then courier.store("logs", lp)
  if !getOrElse(template, "screenshots", false) then courier.store("screenshots", ss)

  # Initialize Casper
  casper.start()

  # Setup viewport
  _.defaults(template, {viewport: {width: 1920, height: 1080}})
  viewport = template.viewport
  casper.viewport viewport.width, viewport.height
  console.log "Viewport: (#{viewport.width}, #{viewport.height})"

  # Log function
  writeLog = (label, dump) ->
    casper.then ->
      ts = (new Date()).toISOString()
      os = system.os
      log = {
        "os.name": os.name
        "os.version": os.version
        "log": dump
      }
      fs.write "#{lp}#{label}.result.#{ts.replace(///[\:]///g, "")}.json", JSON.stringify(log, null, 2)

  # Section loops
  setNumber = 0

  stepLoop = (step) -> actions.step(step, courier, casper)

  testLoop = ()->
    # Begin the tests
    startTime = (new Date())
    casper.then ->
      name = getOrElse(template, "name", "Test")
      @echo "Test: #{name}";
      @echo ""
      _.each getOrElse(template, "step", []), stepLoop
    casper.then ->
      executionTime = ((new Date() - startTime) / 1000).toFixed(2)
      @echo "Test took #{executionTime} seconds to complete."

  setLoop = (set) ->
    casper.then ->
      _.defaults(set, {
        logs: template.logs
        name: template.name
      }) # extend set from template data
      if _.isObject set then courier.pushSet(set)
      setNumber += 1
      @echo "\nData Set \##{setNumber}"
      testLoop()

  # Build action stack
  if _.isArray setData
    _.forEach setData, setLoop
  else
    testLoop()
  casper.then ->
    name = getOrElse(template, "name", "Test")
    writeLog(name, courier.dump())

  # Start Tests
  console.log ""
  console.log "Test(s) Starting"
  console.log "..."
  casper.run()