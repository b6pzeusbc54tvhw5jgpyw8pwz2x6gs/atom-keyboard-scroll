{Point, CompositeDisposable} = require "atom"
{jQuery} = require 'atom-space-pen-views'

linesToScrollTotal = 0
to = 0

SCROLL_OFF = 2

animationTarget = null
isRepeating = false
animationRunning = false
targetScrollTop = 0
targetScreenRow = 0
targetFirstRow = 0
cursorRowFromVisibleTop = 0

getConfig = ( configName )->
  withCursor = atom.config.get 'keyboard-scroll.'+configName

module.exports =
  config:
    linesToScrollSingle:
      type: "number"
      default: 3
      title: "Number of lines to scroll for a single hit"

    linesToScrollKeydown:
      type: "number"
      default: 2
      title: "Number of lines to scroll for key down"

    animate:
      type: "boolean"
      default: true
      title: "Animate scroll"

    animationDuration:
      type: "number"
      default: 150
      title: "Duration of animation in milliseconds"

    animateScreenScroll:
      type: "boolean"
      default: true
      title: "Animate ScreenScroll"

    screenScrollAnimationDuration:
      type: "number"
      default: 350
      title: "Duration of animation in milliseconds for ScreenScroll"

  subscriptions: null

  activate: ->
    @subscriptions = new CompositeDisposable()

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollUpWithCursor": (e) =>
        @scrollUp(e.originalEvent.repeat, true)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollDownWithCursor": (e) =>
        @scrollDown(e.originalEvent.repeat, true)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollUp": (e) =>
        @scrollUp(e.originalEvent.repeat, false)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollDown": (e) =>
        @scrollDown(e.originalEvent.repeat, false)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollHalfScreenDown": (e) =>
        @scrollHalfScreenDown(e.originalEvent.repeat, false)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollHalfScreenUp": (e) =>
        @scrollHalfScreenUp(e.originalEvent.repeat, false)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollFullScreenDown": (e) =>
        @scrollFullScreenDown(e.originalEvent.repeat, false)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollFullScreenUp": (e) =>
        @scrollFullScreenUp(e.originalEvent.repeat, false)

  deactivate: ->
    @subscriptions.dispose()

  animate: ( linesToScroll, options ) ->
    editor = atom.workspace.getActiveTextEditor()
    pxToScroll = editor.getLineHeightInPixels() * linesToScroll
    from = editor.getScrollTop()
    maxScrollTop = editor.getMaxScrollTop()-1

    if animationRunning
      to += pxToScroll
    else
      to = from + pxToScroll

    if (from < 0 and to < 0) or (from > maxScrollTop and to > maxScrollTop)
      return

    done = ->
      animationRunning = false

    @startAnimation from, to, options.duration, done


  startAnimation: ( from, to, duration=0, done ) ->
    editor = atom.workspace.getActiveTextEditor()
    step = (currentStep) ->
      editor.setScrollTop(currentStep)

    animationRunning = true
    animationTarget = jQuery({top: from}).animate { top: to }, {
      duration: duration
      easing: "swing"
      step: step
      done: done
    }

  restoreCursor: (newFirstRow, linesToScroll) ->
    editor = atom.workspace.getActiveTextEditor()
    newLastRow = newFirstRow + editor.getRowsPerPage()

    if( linesToScroll > 0 )
      for cursor in editor.getCursors()
        position = cursor.getScreenPosition()
        if position.row <= newFirstRow + SCROLL_OFF
          cursor.setScreenPosition([
            newFirstRow + linesToScroll-1
            position.column
          ], autoscroll: false)
    else
      for cursor in editor.getCursors()
        position = cursor.getScreenPosition()
        # console.log position.row,'>=', newLastRow - SCROLL_OFF
        if position.row >= newLastRow - SCROLL_OFF
          cursor.setScreenPosition([
            newLastRow + linesToScroll
            position.column
          ], autoscroll: false)

          # console.log 'newRow:' + (newLastRow+linesToScroll)

  doKeepCursorPosition: (cursorRowFromVisibleTop) ->

    editor = atom.workspace.getActiveTextEditor()
    cursor = editor.getLastCursor()

    if animationRunning
      firstScreenRow = targetFirstRow
    else
      editorElement = atom.views.getView editor
      firstScreenRow = editorElement.getFirstVisibleScreenRow()

    # console.log firstScreenRow + cursorRowFromVisibleTop
    cursor.setScreenPosition([
      firstScreenRow + cursorRowFromVisibleTop,
      cursor.getScreenRow()
    ], autoscroll: false )

  doMoveCursor: (linesToScroll) ->
    editor = atom.workspace.getActiveTextEditor()
    editor.moveDown linesToScroll

  doScroll: (isKeydown, moveCursor, linesToScroll, isScreenScroll) ->

    editor = atom.workspace.getActiveTextEditor()
    editorElement = atom.views.getView editor
    scrollTop = editorElement.getScrollTop()
    pxToScroll = editor.getLineHeightInPixels() * linesToScroll

    if animationRunning
      targetFirstRow = targetFirstRow
    else
      targetFirstRow = editorElement.getFirstVisibleScreenRow()
    targetFirstRow += linesToScroll

    if isScreenScroll
      animationConfig = getConfig 'animateScreenScroll'
    else
      animationConfig = getConfig 'animate'

    isAnimation = animationConfig and not isKeydown
    firstAnimation = isAnimation and not animationRunning

    if isScreenScroll and not animationRunning
      cursor = editor.getLastCursor()
      cursorRowFromVisibleTop = cursor.getScreenRow() -
         editorElement.getFirstVisibleScreenRow()

    if isAnimation
      if isScreenScroll
        duration = getConfig 'screenScrollAnimationDuration'
      else
        duration = getConfig 'animationDuration'

      linesToScrollTotal += linesToScroll
      animationTarget.stop() if animationRunning
      @animate linesToScroll, duration: duration

    else
      editorElement.setScrollTop( scrollTop + pxToScroll )

    @doMoveCursor linesToScroll if moveCursor
    @restoreCursor( targetFirstRow, linesToScroll ) if not isScreenScroll
    @doKeepCursorPosition cursorRowFromVisibleTop if isScreenScroll

  getLinesToScroll: (isKeydown) ->

    if isKeydown
      linesToScroll = getConfig('linesToScrollKeydown')
    else
      linesToScroll = getConfig('linesToScrollSingle')

  getFullLinesToScroll: (direction=1) ->
    editor = atom.workspace.getActiveTextEditor()
    linesToScroll = editor.getHeight() / editor.getLineHeightInPixels()
    linesToScroll = Math.floor linesToScroll
    linesToScroll

  getHalfLinesToScroll: (direction=1) ->
    editor = atom.workspace.getActiveTextEditor()
    linesToScroll = editor.getHeight() / editor.getLineHeightInPixels()
    linesToScroll = linesToScroll / 2
    linesToScroll = Math.floor linesToScroll
    linesToScroll

  scrollUp: (isKeydown, moveCursor) ->
    linesToScroll = @getLinesToScroll isKeydown
    linesToScroll = -1*linesToScroll
    @doScroll(isKeydown, moveCursor, linesToScroll)

  scrollDown: (isKeydown, moveCursor) ->
    linesToScroll = @getLinesToScroll isKeydown
    @doScroll(isKeydown, moveCursor, linesToScroll)

  scrollFullScreenUp: (isKeydown, moveCursor) ->
    linesToScroll = -1*@getFullLinesToScroll()
    @doScroll isKeydown, moveCursor, linesToScroll, true
    # @doMoveCursor linesToScroll unless isKeydown

  scrollFullScreenDown: (isKeydown, moveCursor) ->
    linesToScroll = @getFullLinesToScroll()
    @doScroll isKeydown, moveCursor, linesToScroll, true

  scrollHalfScreenUp: (isKeydown, moveCursor) ->
    linesToScroll = -1*@getHalfLinesToScroll()
    @doScroll isKeydown, moveCursor, linesToScroll, true

  scrollHalfScreenDown: (isKeydown, moveCursor) ->
    linesToScroll = @getHalfLinesToScroll()
    @doScroll isKeydown, moveCursor, linesToScroll, true
