{CompositeDisposable, BufferedProcess} = require 'atom'
fs = require('fs')
path = require('path')
temp = require('temp')

promiseWrap = (obj, methodName) ->
  return (args...) ->
    return new Promise((resolve, reject) ->
      obj[methodName](args..., (err, result) ->
        return reject(err) if err
        resolve(result)
      )
    )

mkdir = promiseWrap(temp, 'mkdir')
writeFile = promiseWrap(fs, 'writeFile')
unlink = promiseWrap(fs, 'unlink')

module.exports =
  config:
    executablePath:
      type: 'string'
      default: ''
      description: 'Anubis compiler executable path'
    executableName:
      type: 'string'
      default: 'anubis'
      description: 'Anubis compiler executable name'
    compilerArguments:
      type: 'string'
      default: ''
      description: 'Additional compiler arguments'

  activate: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'linter-anubis.executablePath',
      (executablePath) =>
        @executablePath = executablePath
    @subscriptions.add atom.config.observe 'linter-anubis.executableName',
      (executableName) =>
        @executableName = executableName
    @subscriptions.add atom.config.observe 'linter-anubis.compilerArguments',
      (compilerArguments) =>
        @compilerArguments = compilerArguments
    console.log 'linter-anubis activated' if atom.inDevMode()

  deactivate: ->
    @subscriptions.dispose()

  provideLinter: ->
    provider =
        grammarScopes: ['source.anubis', 'source.a2a']
        scope: 'file'
        lintOnFly: true

        processMessage: (type, path, message, line_start, char_start) ->
          {
            type: type,
            text: message,
            filePath: path,
            range: [
                [line_start - 1, char_start - 1],
                [line_start - 1, char_start - 2],
            ]
          }

        lint: (textEditor) =>
          return new Promise (resolve, reject) =>
            file_path = textEditor.getPath()

            process_options =
              cwd: path.dirname(file_path)
              env: process.env

            command = @executablePath + @executableName

            # took that off the official linter package, maybe there is a way to do it with the API but for now, this work!
            mkdir('AtomLinter-Anubis').then((tmpDir) =>
              tmp_file = path.join(tmpDir, path.basename(file_path))

              writeFile(tmp_file, textEditor.getText()).then(=>
                anubis_output = []

                args = ['-syntax_only_1', '-nocolor', atom.config.get('linter-anubis.compilerArguments'), tmp_file]

                stdout = (data) =>
                  anubis_output.push data

                stderr = (data) =>
                  anubis_output.push data

                exit = (code) =>
                  if code != 1
                    console.log("[linter-anubis] The Anubis compiler exited with code " + code) if atom.inDevMode()
                    return resolve []

                  messages = []
                  anubis_output = anubis_output.join('\n')

                  match_arr = []
                  regex = /^(.+) \(line (\d+), column (\d+)\) \w+ (E|W)(\d+):\n\s*(.+)(?:# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #)?/gm

                  while ((match_arr = regex.exec(anubis_output)) != null)
                    if match_arr[4] == 'W'
                      messages.push(provider.processMessage('Warning', file_path, match_arr[6], parseInt(match_arr[2], 10), parseInt(match_arr[3], 10)))
                    else if match_arr[4] == 'E'
                      messages.push(provider.processMessage('Error',   file_path, match_arr[6], parseInt(match_arr[2], 10), parseInt(match_arr[3], 10)))

                  resolve messages
                  unlink(tmp_file).then(-> fs.rmdir(tmpDir))

                anubis_process = new BufferedProcess({command, args, process_options, stdout, stderr, exit})

                anubis_process.onWillThrowError ({error,handle}) ->
                  atom.notifications.addError "Failed to run #{@executablePath + @executableName}",
                    detail: "#{error.message}"
                    dismissable: true
                  handle()
                  resolve []
              )
            )
