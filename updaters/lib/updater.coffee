# Copyright 2013 Andrey Sitnik <andrey@sitnik.ru>,
# sponsored by Evil Martians.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

https = require('https')
fs    = require('fs')

module.exports =

  # Can I Use browser names to internal
  browsers:
    firefox: 'ff'
    chrome:  'chrome'
    safari:  'safari'
    ios_saf: 'ios'
    opera:   'opera'
    ie:      'ie'
    bb:      'bb'
    android: 'android'

  # Count of loading HTTP requests
  requests: 0

  # Execute `callback`, when all `caniuse` request will be finished.
  done: (callback) ->
    @doneCallback = callback

  # Load file from GitHub RAWs
  github: (path, callback) ->
    @requests += 1
    https.get "https://raw.github.com/#{path}", (res) =>
      data = ''
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', =>
        callback(JSON.parse(data))
        @requests -= 1
        @doneCallback?() if @requests == 0

  # Parse browsers list in feature file
  parse: (data) ->
    need = []
    for browser, versions of data.stats
      for interval, support of versions
        for version in interval.split('-')
          if @browsers[browser] and support.match(/\sx($|\s)/)
            version = version.replace(/\.0$/, '')
            need.push(@browsers[browser] + ' ' + version)
    need

  # Can I Use shortcut to request files in features/ dir.
  feature: (file, callback) ->
    url = "Fyrd/caniuse/master/features-json/#{file}"
    @github url, (data) => callback @parse(data)

  # Get Can I Use features from another user fork
  fork: (fork, file, callback) ->
    [user, branch] = fork.split('/')
    url = "#{user}/caniuse/#{branch}/features-json/#{file}"
    @github url, (data) => callback @parse(data)

  # Call callback with list of all browsers
  all: (callback) ->
    browsers = require('../../data/browsers')
    list = []
    for name, data of browsers
      for version in data.versions
        list.push(name + ' ' + version)
    callback(list)

  # Return string of object. Like `JSON.stringify`, but output CoffeeScript.
  stringify: (obj, indent = '') ->
    if obj instanceof Array
      local = indent + '  '
      "[\n#{local}" +
        obj.map( (i) => @stringify(i, local) ).join("\n#{local}") +
      "\n#{indent}]"

    else if typeof(obj) == 'object'
      local = indent + '  '

      processed = []
      for key, value of obj
        key = "\"#{key}\"" if key.match(/'|-|@|:/)
        value = @stringify(value, local)
        value = ' ' + value unless value[0] == "\n"
        processed.push(key + ':' + value)

      "\n" + local + processed.join("\n#{local}") + "\n"

    else
      JSON.stringify(obj)

  # Save autogenerated `file` with warning comment and node.js exports.
  save: (file, json) ->
    sorted = {}
    sorted[key] = json[key] for key in Object.keys(json).sort()

    file     = "#{__dirname}/../../data/#{file}"
    content  = "# Don't edit this files, because it's autogenerated.\n" +
               "# See updaters/ dir for generator. Run bin/update to update." +
               "\n\n"
    content += "module.exports =" + @stringify(sorted) + ";\n"
    fs.writeFileSync(file + '.coffee', content)
