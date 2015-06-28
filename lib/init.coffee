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
    console.log 'linter-anubis activated'
