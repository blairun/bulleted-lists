{CompositeDisposable} = require "atom"


module.exports =

  config:
    midLineContinuation:
      type: "boolean"
      default: true
      description: "Continue lists when cursor is in the middle of an
        existing bulleted line and Enter is pressed."
    quickNewListItems:
      type: "boolean"
      default: true
      description: "Create bulleted line when cursor is at end of normal
        line and Tab is pressed."
    addStrikeThroughEquivalent:
      type: "boolean"
      default: false
      description: "Add/recognize 'x' as a bullet. May require restart."

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
