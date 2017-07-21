{CompositeDisposable} = require "atom"

# config = require "./config"
# basicConfig = require "./config-basic"

module.exports =
  # config: basicConfig

  modules: {} # To cache required modules
  disposables: null # Composite disposable

  activate: ->
    @disposables = new CompositeDisposable()

    # @registerWorkspaceCommands()
    @registerEditorCommands()

  deactivate: ->
    @disposables?.dispose()
    @disposables = null
    @modules = {}

  registerEditorCommands: ->
    editorCommands = {}

    ["insert-new-line", "indent-list-line", "outdent-list-line", "home-list-line"].forEach (command) =>
      editorCommands["bulleted-lists:#{command}"] =
        @registerCommand("./edit-line",
          args: command, skipList: ["autocomplete-active"])

    @disposables.add(atom.commands.add("atom-text-editor", editorCommands))

  registerView: (path, options = {}) ->
    (e) =>
      # if (options.optOutGrammars || @isMarkdown()) && !@inSkipList(options.skipList)
        @modules[path] ?= require(path)
        moduleInstance = new @modules[path](options.args)
        moduleInstance.display() # unless config.get("_skipAction")?
      # else
      #  e.abortKeyBinding()

  registerCommand: (path, options = {}) ->
    (e) =>
        @modules[path] ?= require(path)
        moduleInstance = new @modules[path](options.args)
        moduleInstance.trigger(e)
