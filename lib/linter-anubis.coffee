linterPath = atom.packages.getLoadedPackage("linter").path

Linter = require "#{linterPath}/lib/linter"

class LinterAnubis extends Linter
  @syntax: ['source.anubis', 'source.a2a']

  executablePath: null

  cmd: ['anubis']

  linterName: 'anubis'

  # A regex pattern used to extract information from the executable's output.
  regex:
    '^(?<file>.+) \\(line (?<line>\\d+), column (?<col>\\d+)\\) \\w+ (?<type>(?<error>E)|(?<warning>W))(?<code>\\d+):\n(?<message>.+)(?:# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #)?'

  regexFlags: 's'

  constructor: (editor)->
    super(editor)

    @executableDirListener = atom.config.observe 'linter-anubis.executablePath', =>
      executablePath = atom.config.get 'linter-anubis.executablePath'

      if executablePath
        @executablePath = if executablePath.length > 0 then executablePath else null

    @binaryNameListener = atom.config.observe 'linter-anubis.executableName', =>
      @updateCommand()

  destroy: ->
    @executableDirListener.dispose()
    @binaryNameListener.dispose()

  updateCommand: ->
    binary_name = atom.config.get 'linter-anubis.executableName'

    cmd = [binary_name]

    cmd.push '-syntax_only_1'
    cmd.push '-nocolor'
    cmd.push atom.config.get 'linter-anubis.compilerArguments'

    @cmd = cmd

module.exports = LinterAnubis
