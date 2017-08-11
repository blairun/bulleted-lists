# config = require "./config"
LineMeta = require "./line-meta"

MAX_SKIP_EMPTY_LINE_ALLOWED = 5

module.exports =
class EditLine
  # actions: insert-new-line, indent-list-line, outdent-list-line, home-list-line
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
    i = line.search(/\S/) # returns index of first non-space character
    # console.log(cursor.column)
    # console.log(line.search(/\S/))
    # console.log(i)
    # console.log(line.replace(/^\s+|\s+$/g,'').length)
    # console.log(atom.config.get("bulleted-lists.midLineContinuation"))

    # when cursor is in the middle of a line, do a normal newline unless inline continuation is enabled
    # also normal newline when cursor is anywhere before the first character of a line
    if (cursor.column <= line.search(/\S/)) ||
    (cursor.column < i + line.replace(/^\s+|\s+$/g,'').length && !atom.config.get("bulleted-lists.midLineContinuation"))
      # console.log("abort1")
      return e.abortKeyBinding()

    lineMeta = new LineMeta(line)
    if lineMeta.isContinuous()
      if lineMeta.isEmptyBody()
        @_insertNewlineWithoutContinuation(cursor)
      else
        @_insertNewlineWithContinuation(lineMeta.nextLine, selection)
    else
      # console.log("abort2")
      e.abortKeyBinding()

  _insertNewlineWithContinuation: (nextLine, selection) ->
    # remove trailing space(s) before before moving to new line
    # console.log("continue list")
    cursor = selection.getHeadBufferPosition()
    line = @editor.lineTextForBufferRow(cursor.row)
    # console.log(line)
    @editor.selectToBeginningOfLine()
    lineLeft = selection.getText()
    lineLeft = lineLeft.replace(/\s+$/, '')
    # console.log(lineLeft)
    # console.log(cursor.column)
    # console.log(lineLeft.length)
    if cursor.column >= lineLeft.length
      @editor.insertText(lineLeft)

      # don't remove space when cursor is directly after a bullet
      lineLeft = lineLeft.replace(/^\s+|\s+$/g,'')
      # console.log(lineLeft.length)
      if lineLeft.length <= 1
        # console.log("space")
        @editor.insertText(" ")

    @editor.insertText("\n#{nextLine}")
    cursor = selection.getHeadBufferPosition()
    # line = @editor.lineTextForBufferRow(cursor.row)
    @editor.selectToEndOfLine()
    lineRight = selection.getText()
    # console.log(cursor.column)
    # console.log(lineRight.length)
    lineRight = lineRight.replace(/^\s+|\s+$/g,'')
    # console.log(lineRight.length)
    @editor.insertText(lineRight)
    # next line fixes issue where mid line contiunation of wrapped text puts
    # cursor at the end of the first row rather than end of the new bulleted line,
    # so pressing enter again would split the wrapped line
    @editor.moveToEndOfLine()

  _insertNewlineWithoutContinuation: (cursor) ->
    # console.log("discontinue list")
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
    i = line.search(/\S/) # returns index of first non-space character

    if LineMeta.isList(line)
      if line.substring(i, i+1) == "-"
        # console.log(line.length - i)
        if line.length - i <= 2
          # indent bullet (without cycling) when there is no text after the bullet
          selection.indentSelectedRows()
        else
          @_beforeTabbing(selection)
          @editor.insertText("~")
          @editor.moveToEndOfLine()
      else if line.substring(i, i+1) == "~"
        @_beforeTabbing(selection)
        @editor.insertText("+")
        @editor.moveToEndOfLine()
      else if line.substring(i, i+1) == "+"
        @_beforeTabbing(selection)
        if atom.config.get("bulleted-lists.addStrikeThroughEquivalent")
          @editor.insertText("x")
          @editor.moveToEndOfLine()
        else
          @editor.insertText("-")
          @editor.moveToEndOfLine()
          selection.indentSelectedRows()
      else if line.substring(i, i+1) == "x"
        @_beforeTabbing(selection)
        @editor.insertText("-")
        @editor.moveToEndOfLine()
        selection.indentSelectedRows()
      else
        selection.indentSelectedRows()

    else if @_isAtLineBeginning(line, cursor.column) # indent on start of line
      selection.indent()
    else
      # create list item when tab is pressed and cursor is at end of line
      # console.log("cursor: ", cursor.column)
      # console.log("beginning space: ", i)
      # console.log("length: ", line.replace(/^\s+|\s+$/g,'').length)
      # console.log(atom.config.get("bulleted-lists.quickNewListItems"))
      if cursor.column >= i + line.replace(/^\s+|\s+$/g,'').length && atom.config.get("bulleted-lists.quickNewListItems")
        @editor.moveToBeginningOfLine()
        @editor.moveToFirstCharacterOfLine()
        @editor.insertText("- ")
        @editor.moveToEndOfLine()
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
    # return e.abortKeyBinding() if @_isRangeSelection(selection)

    if @_isRangeSelection(selection)
      # regMatch = /^(\*|#|1\.)\s*/g
      regMatch1 = /\n(-|~|\+|x)\s/g
      SelectionRangeRows = selection.getBufferRowRange() # Instead of selection.getBufferRange()
      beginRow = SelectionRangeRows[0]
      endRow = SelectionRangeRows[1]
      # check one row above first selected row to account for newline character
      SelectionRange1 = [[beginRow - 1, 0], [endRow, @editor.lineTextForBufferRow(endRow).length]]

      # abort if there is no fully outdented match
      if !regMatch1.test(@editor.getTextInBufferRange(SelectionRange1))
        # console.log(@editor.getTextInBufferRange(SelectionRange1))
        # console.log("no fully outdented match")
        return e.abortKeyBinding()

      # remove bullets if at least one row is fully outdented
      @editor.backwardsScanInBufferRange(regMatch1, SelectionRange1, (match) =>
        # console.log("fully outdented match")
        regMatch2 = /(-|~|\+|x)\s/g
        SelectionRange2 = [[beginRow, 0], [endRow, @editor.lineTextForBufferRow(endRow).length]]
        @editor.backwardsScanInBufferRange(regMatch2, SelectionRange2, (match) -> match.replace(""))
        return)
      return

    # console.log("no range selection")
    cursor = selection.getHeadBufferPosition()
    line = @editor.lineTextForBufferRow(cursor.row)
    i = line.search(/\S/) # returns index of first non-space character

    if LineMeta.isList(line)
      # i = line.search(/\S/) # returns index of first non-space character
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
      else if line.substring(i, i+1) == "x"
        @_beforeTabbing(selection)
        @editor.insertText("+")
        @editor.moveToEndOfLine()
      else
        selection.outdentSelectedRows()

    else if @_isAtLineBeginning(line, cursor.column) # outdent on start of line
      selection.outdentSelectedRows()
      # backspace after final out dent
      if cursor.column == 0
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


  # home should take you to beginning of text (rather than bullet)
  homeListLine: (e, selection) ->
    return e.abortKeyBinding() if @_isRangeSelection(selection)

    cursor = selection.getHeadBufferPosition()
    line = @editor.lineTextForBufferRow(cursor.row)

    @editor.selectToBeginningOfLine()
    lineLeft = selection.getText()
    lineLeft = lineLeft.replace(/^\s+|\s+$/g,'')
    # console.log(lineLeft.length)

    if LineMeta.isList(line) && !@_isAtLineBeginning(line, cursor.column) &&  lineLeft.length > 1
      # console.log("home")
      @editor.moveToFirstCharacterOfLine()
      @editor.moveToBeginningOfNextWord()

    # abortKeyBinding doesn't work as expected when cursor is at beginning of line
    else if cursor.column == 0
      @editor.moveToFirstCharacterOfLine()
    else if @_isAtLineBeginning(line, cursor.column)
      @editor.moveToBeginningOfLine()

    else
      # console.log("abort home")
      e.abortKeyBinding()

  _isRangeSelection: (selection) ->
    head = selection.getHeadBufferPosition()
    tail = selection.getTailBufferPosition()

    head.row != tail.row || head.column != tail.column

  _isAtLineBeginning: (line, col) ->
    col == 0 || line.substring(0, col).trim() == ""
