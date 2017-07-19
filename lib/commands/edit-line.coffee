config = require "../config"
LineMeta = require "../helpers/line-meta"

MAX_SKIP_EMPTY_LINE_ALLOWED = 5

module.exports =
class EditLine
  # action: insert-new-line, indent-list-line
  constructor: (action) ->
    @action = action
    @editor = atom.workspace.getActiveTextEditor()

  trigger: (e) ->
    fn = @action.replace /-[a-z]/ig, (s) -> s[1].toUpperCase()

    @editor.transact =>
      @editor.getSelections().forEach (selection) =>
        @[fn](e, selection)

  insertNewLine: (e, selection) ->
    return e.abortKeyBinding() if @_isRangeSelection(selection)

    cursor = selection.getHeadBufferPosition()
    line = @editor.lineTextForBufferRow(cursor.row)
    # console.log(line.search(/\S/))
    # console.log(cursor.column)

    # when cursor is at middle of line, do a normal insert line unless inline continuation is enabled
    # also normal newline when cursor is anywhere before the first character of a line
    if (cursor.column <= line.search(/\S/)) || (cursor.column < line.length && !config.get("inlineNewLineContinuation"))
      return e.abortKeyBinding()

    lineMeta = new LineMeta(line)
    if lineMeta.isContinuous()
      if lineMeta.isEmptyBody()
        @_insertNewlineWithoutContinuation(cursor)
      else
        @_insertNewlineWithContinuation(lineMeta.nextLine, selection)
    else
      e.abortKeyBinding()

  _insertNewlineWithContinuation: (nextLine, selection) ->
    # remove trailing space(s) before before moving to new line
    cursor = selection.getHeadBufferPosition()
    line = @editor.lineTextForBufferRow(cursor.row)
    # console.log(line)
    @editor.selectToBeginningOfLine()
    line = selection.getText()
    line = line.replace(/\s+$/, '')
    # console.log(line)
    # console.log(cursor.column)
    # console.log(line.length)
    if cursor.column >= line.length
      @editor.insertText(line)
    @editor.insertText("\n#{nextLine}")

  _insertNewlineWithoutContinuation: (cursor) ->
    nextLine = "\n"
    currentIndentation = @editor.indentationForBufferRow(cursor.row)

    # if it is an indented empty list, we will go up lines and try to find
    # its parent's list prefix and use that if possible
    if currentIndentation > 0 && cursor.row > 1
      emptyLineSkipped = 0

      for row in [(cursor.row - 1)..0]
        line = @editor.lineTextForBufferRow(row)

        if line.trim() == "" # skip empty lines in case of list paragraphs
          break if emptyLineSkipped > MAX_SKIP_EMPTY_LINE_ALLOWED
          emptyLineSkipped += 1
        else # find parent with indentation = current indentation - 1
          indentation = @editor.indentationForBufferRow(row)
          continue if indentation >= currentIndentation
          nextLine = new LineMeta(line).nextLine if indentation == currentIndentation - 1 && LineMeta.isList(line)
          break

    @editor.selectToBeginningOfLine()
    @editor.insertText(nextLine)

  indentListLine: (e, selection) ->
    return e.abortKeyBinding() if @_isRangeSelection(selection)

    cursor = selection.getHeadBufferPosition()
    line = @editor.lineTextForBufferRow(cursor.row)

    if LineMeta.isList(line)
      i = line.search(/\S/) # returns index of first non-space character
      if line.substring(i, i+1) == "-"
        @_beforeTabbing(selection)
        @editor.insertText("~")
        @editor.moveToEndOfLine()
      else if line.substring(i, i+1) == "~"
        @_beforeTabbing(selection)
        @editor.insertText("+")
        @editor.moveToEndOfLine()
      else if line.substring(i, i+1) == "+"
        @_beforeTabbing(selection)
        @editor.insertText("-")
        @editor.moveToEndOfLine()
        selection.indentSelectedRows()
      else
        selection.indentSelectedRows()

    else if @_isAtLineBeginning(line, cursor.column) # indent on start of line
      selection.indent()
    else
      e.abortKeyBinding()

  _isAtLineBeginning: (line, col) ->
    col == 0 || line.substring(0, col).trim() == ""

  _isRangeSelection: (selection) ->
    head = selection.getHeadBufferPosition()
    tail = selection.getTailBufferPosition()

    head.row != tail.row || head.column != tail.column

  _beforeTabbing: (selection) ->
    # necessary for tabbing with soft line wrap enabled
    @editor.moveToBeginningOfLine()
    @editor.moveToFirstCharacterOfLine()
    selection.selectRight()

  outdentListLine: (e, selection) ->
    return e.abortKeyBinding() if @_isRangeSelection(selection)

    cursor = selection.getHeadBufferPosition()
    line = @editor.lineTextForBufferRow(cursor.row)
    # console.log("indent")

    if LineMeta.isList(line)
      i = line.search(/\S/) # returns index of first non-space character
      if line.substring(i, i+1) == "-"
        selection.outdentSelectedRows()
        @editor.moveToEndOfLine()
        if line.substring(0, 1) == "-"
          @_beforeTabbing(selection)
          selection.selectRight()
          selection.delete()
      else if line.substring(i, i+1) == "~"
        @_beforeTabbing(selection)
        @editor.insertText("-")
        @editor.moveToEndOfLine()
      else if line.substring(i, i+1) == "+"
        @_beforeTabbing(selection)
        @editor.insertText("~")
        @editor.moveToEndOfLine()
      else
        selection.outdentSelectedRows()

    else if @_isAtLineBeginning(line, cursor.column) # outdent on start of line
      selection.outdentSelectedRows()
      # backspace after final out dent
      # console.log("backspace beginning")
      selection.backspace()

      # if cursor isn't the beginning of a line and if it isn't following a space then add space
      cursor = selection.getHeadBufferPosition()
      line = @editor.lineTextForBufferRow(cursor.row)
      if cursor.column != 0 && line.substring(cursor.column, cursor.column-1) != " "
        @editor.insertText(" ")
    else
      e.abortKeyBinding()

  _isAtLineBeginning: (line, col) ->
    col == 0 || line.substring(0, col).trim() == ""

  _isRangeSelection: (selection) ->
    head = selection.getHeadBufferPosition()
    tail = selection.getTailBufferPosition()

    head.row != tail.row || head.column != tail.column

  _beforeTabbing: (selection) ->
    # necessary for tabbing with soft line wrap enabled
    @editor.moveToBeginningOfLine()
    @editor.moveToFirstCharacterOfLine()
    selection.selectRight()