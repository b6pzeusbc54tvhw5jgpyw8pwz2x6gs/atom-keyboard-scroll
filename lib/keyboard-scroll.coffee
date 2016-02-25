{Point, CompositeDisposable} = require "atom"
{jQuery} = require 'atom-space-pen-views'

isRepeating = false
animationRunning = false
linesToScrollTotal = 0
to = 0
animationTarget = null

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
      default: 400
      title: "Duration of animation in milliseconds for ScreenScroll"

    screenScrollWithCursor:
      type: "boolean"
      default: true
      title: "ScrollHalfScreen and ScrollFullScreen do scroll with cursor"

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
        withCursor = getConfig 'screenScrollWithCursor'
        @scrollHalfScreenDown(e.originalEvent.repeat, withCursor)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollHalfScreenUp": (e) =>
        withCursor = getConfig 'screenScrollWithCursor'
        @scrollHalfScreenUp(e.originalEvent.repeat, withCursor)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollFullScreenDown": (e) =>
        withCursor = getConfig 'screenScrollWithCursor'
        @scrollFullScreenDown(e.originalEvent.repeat, withCursor)

    @subscriptions.add atom.commands.add "atom-text-editor",
      "keyboard-scroll:scrollFullScreenUp": (e) =>
        withCursor = getConfig 'screenScrollWithCursor'
        @scrollFullScreenUp(e.originalEvent.repeat, withCursor)

  deactivate: ->
    @subscriptions.dispose()

  animate: (linesToScroll, isScreenScroll) ->

    editor = atom.workspace.getActiveTextEditor()
    pxToScroll = editor.getLineHeightInPixels() * linesToScroll
    from = editor.getScrollTop()
    maxScrollTop = editor.getMaxScrollTop()-1

    if animationRunning
      to += pxToScroll
    else
      to = from + pxToScroll

    if getConfig('animate') and not isScreenScroll
      animationDuration = getConfig('animationDuration')
    else if getConfig('animateScreenScroll') and isScreenScroll
      animationDuration = getConfig('screenScrollAnimationDuration')

    if (from < 0 and to < 0) or (from > maxScrollTop and to > maxScrollTop)
      return

    done = =>
      animationRunning = false
      if isScreenScroll && getConfig 'screenScrollWithCursor'
        @doMoveCursor linesToScrollTotal

      linesToScrollTotal = 0
      setTimeout () =>
        @restoreCursor()
      200

    @startAnimation from, to, animationDuration, done


  startAnimation: ( from, to, animationDuration=0, done ) ->
    editor = atom.workspace.getActiveTextEditor()
    step = (currentStep) ->
      editor.setScrollTop(currentStep)

    animationRunning = true
    animationTarget = jQuery({top: from}).animate { top: to }, {
      duration: animationDuration
      easing: "swing"
      step: step
      done: done
    }


  restoreCursor: () ->
    editor = atom.workspace.getActiveTextEditor()
    cursor = editor.getLastCursor()
    firstVisibleRow = editor.getFirstVisibleScreenRow()
    # lastVisibleRow = editor.getLastVisibleScreenRow() # atom bug
    lastVisibleRow = firstVisibleRow + editor.getRowsPerPage()
    currentPosition = cursor.getScreenPosition()

    if currentPosition.row < firstVisibleRow
      editor.setCursorScreenPosition
        row: firstVisibleRow+2, column: currentPosition.column

    else if currentPosition.row > lastVisibleRow
      editor.setCursorScreenPosition
        row: lastVisibleRow-2, column: currentPosition.column

  doMoveCursor: (linesToScroll) ->
    editor = atom.workspace.getActiveTextEditor()
    editor.moveDown linesToScroll

  doScroll: (isKeydown, moveCursor, linesToScroll, isScreenScroll) ->

    editor = atom.workspace.getActiveTextEditor()
    pxToScroll = editor.getLineHeightInPixels() * linesToScroll
    scrollTop = editor.getScrollTop()

    if isScreenScroll
      notAnimation = not getConfig 'animateScreenScroll'
    else
      notAnimation = not getConfig 'animate'

    notAnimation = notAnimation or (isKeydown and not animationRunning)

    if notAnimation

      unless isRepeating
        isRepeating = true
        view = atom.views.getView atom.workspace
        onKeyup = =>
          isRepeating = false
          view.removeEventListener 'keyup', onKeyup
          @restoreCursor()

        view.addEventListener 'keyup', onKeyup

      @doMoveCursor linesToScroll if moveCursor
      editor.setScrollTop( scrollTop + pxToScroll )

    else if not isKeydown
      linesToScrollTotal += linesToScroll
      animationTarget.stop() if animationRunning
      @animate linesToScroll, isScreenScroll

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
