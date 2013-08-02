Curve = {}

if typeof module != 'undefined'
  module.exports = Curve
else
  window.Curve = Curve

###
  TODO
  * experiment with loading a file then editing it
  * change path -> svgEl in cases where it makes sense
  * removing nodes with keyboard
  * move entire object
  * select/deselect objects
  * make new objects
  * replacing path array updates the interface

  Large
  * how to deal with events and tools and things?
    * like NodeEditor is dragging something, the pointer tool should be deactivated.
    * a tool manager? can push/pop tools?
  * probably need a doc object
    * Can pass it to everything that needs to use svg
    * would have access to the tools n junk
  * proper z-index of elements
    * group for doc at the bottom
    * group for selection
    * group for tool nodes
###

window.main = ->
  svg = SVG("canvas")
  Curve.import(@svg, Curve.Examples.heckert)

  @selectionModel = new Curve.SelectionModel()
  @selectionView = new Curve.SelectionView(svg, @selectionModel)

  @tool = new Curve.PointerTool(svg, {@selectionModel, @selectionView})
  @tool.activate()

window._main = ->
  svg = SVG("canvas")

  @path1 = new Path(svg)
  @path1.addNode(new Node([50, 50], [-10, 0], [10, 0]))
  @path1.addNode(new Node([80, 60], [-10, -5], [10, 5]))
  @path1.addNode(new Node([60, 80], [10, 0], [-10, 0]))
  @path1.close()

  @path2 = new Path(svg)
  @path2.addNode(new Node([150, 50], [-10, 0], [10, 0]))
  @path2.addNode(new Node([220, 100], [-10, -5], [10, 5]))
  @path2.addNode(new Node([160, 120], [10, 0], [-10, 0]))
  @path2.close()

  @path2.svgEl.attr
    fill: 'none'
    stroke: '#333'
    'stroke-width': 2

  @selectionModel = new Curve.SelectionModel()
  @selectionView = new Curve.SelectionView(svg, selectionModel)

  @selectionModel.setSelected(@path1)
  @selectionModel.setSelectedNode(@path1.nodes[2])

  @tool = new Curve.PointerTool(svg, {selectionModel, selectionView})
  @tool.activate()

  @pen = new Curve.PenTool(svg, {selectionModel, selectionView})
  #@pen.activate()

# svg.import.js 0.11 - Copyright (c) 2013 Wout Fierens - Licensed under the MIT license
#
# Converted to coffeescript and modified by benogle

# Convert nodes to svg.js elements
convertNodes = (nodes, context, level, store, block) ->
  for i in [0...nodes.length]
    child = nodes[i]
    attr  = {}
    clips = []

    # get node type
    type = child.nodeName.toLowerCase()

    #  objectify attributes
    attr = objectifyAttributes(child)

    # create elements
    switch type
      when 'path' then element = context[type]()
      when 'polygon' then element = context[type]()
      when 'polyline' then element = context[type]()

      when 'rect' then element = context[type](0,0)
      when 'circle' then element = context[type](0,0)
      when 'ellipse' then element = context[type](0,0)

      when 'line' then element = context.line(0,0,0,0)

      when 'text'
        if child.childNodes.length == 0
          element = context[type](child.textContent)
        else
          element = null

          for j in [0...child.childNodes.length]
            grandchild = child.childNodes[j]

            if grandchild.nodeName.toLowerCase() == 'tspan'
              if element == null
                # first time through call the text() function on the current context
                element = context[type](grandchild.textContent)
              else
                # for the remaining times create additional tspans
                element
                  .tspan(grandchild.textContent)
                  .attr(objectifyAttributes(grandchild))

      when 'image' then element = context.image(attr['xlink:href'])

      when 'g', 'svg'
        element = context[if type == 'g' then 'group' else 'nested']()
        convertNodes(child.childNodes, element, level + 1, store, block)

      when 'defs'
        convertNodes(child.childNodes, context.defs(), level + 1, store, block)

      when 'use'
        element = context.use()

      when 'clippath', 'mask'
        element = context[type == 'mask' ? 'mask' : 'clip']()
        convertNodes(child.childNodes, element, level + 1, store, block)

      when 'lineargradient', 'radialgradient'
        element = context.defs().gradient type.split('gradient')[0], (stop) ->
          for j in [0...child.childNodes.length]
            stop
              .at(objectifyAttributes(child.childNodes[j]))
              .style(child.childNodes[j].getAttribute('style'))

      when '#comment', '#text', 'metadata', 'desc'
        ; # safely ignore these elements
      else
        console.log('SVG Import got unexpected type ' + type, child)

    if element
      # parse transform attribute
      transform = objectifyTransformations(attr.transform)
      delete attr.transform

      # set attributes and transformations
      element
        .attr(attr)
        .transform(transform)

      # store element by id
      store[element.attr('id')] = element if element.attr('id')

      # now that we've set the attributes "rebuild" the text to correctly set the attributes
      element.rebuild() if type == 'text'

      # call block if given
      block.call(element) if typeof block == 'function'

  context

# Convert attributes to an object
objectifyAttributes = (child) ->
  attrs = child.attributes or []
  attr  = {}

  # gather attributes
  if attrs.length
    for i in [attrs.length-1..0]
      attr[attrs[i].nodeName] = attrs[i].nodeValue

  attr

# Convert transformations to an object
objectifyTransformations = (transform) ->
  trans = {}
  list  = (transform or '').match(/[A-Za-z]+\([^\)]+\)/g) || []
  def   = SVG.defaults.trans()

  # gather transformations
  if list.length
    for i in [list.length-1..0]
      # parse transformation
      t = list[i].match(/([A-Za-z]+)\(([^\)]+)\)/)
      v = (t[2] || '').replace(/^\s+/,'').replace(/,/g, ' ').replace(/\s+/g, ' ').split(' ')

      # objectify transformation
      switch t[1]
        when 'matrix'
          trans.a         = parseFloat(v[0]) || def.a
          trans.b         = parseFloat(v[1]) || def.b
          trans.c         = parseFloat(v[2]) || def.c
          trans.d         = parseFloat(v[3]) || def.d
          trans.e         = parseFloat(v[4]) || def.e
          trans.f         = parseFloat(v[5]) || def.f

        when 'rotate'
          trans.rotation  = parseFloat(v[0]) || def.rotation
          trans.cx        = parseFloat(v[1]) || def.cx
          trans.cy        = parseFloat(v[2]) || def.cy

        when 'scale'
          trans.scaleX    = parseFloat(v[0]) || def.scaleX
          trans.scaleY    = parseFloat(v[1]) || def.scaleY

        when 'skewX'
          trans.skewX     = parseFloat(v[0]) || def.skewX

        when 'skewY'
          trans.skewY     = parseFloat(v[0]) || def.skewY

        when 'translate'
          trans.x         = parseFloat(v[0]) || def.x
          trans.y         = parseFloat(v[1]) || def.y

  trans

Curve.import = (svgDocument, svgString) ->
  window.paths = []
  IMPORT_FNS =
    path: (el) -> [new Curve.Path(svgDocument, svgEl: el)]

  # create temporary div to receive svg content
  well = document.createElement('div')
  store = {}

  # properly close svg tags and add them to the DOM
  well.innerHTML = svgString
    .replace(/\n/, '')
    .replace(/<(\w+)([^<]+?)\/>/g, '<$1$2></$1>')

  convertNodes well.childNodes, svgDocument, 0, store, ->
    nodeType = this.node.nodeName
    window.paths = window.paths.concat(IMPORT_FNS[nodeType](this)) if IMPORT_FNS[nodeType]
    null

  # mark temporary div for garbage collection
  well = null

  store

_ = window._ or require 'underscore'
$ = window.jQuery or require 'jquery'

#
class Curve.NodeEditor
  nodeSize: 5
  handleSize: 3

  node = null
  nodeElement = null
  handleElements = null
  lineElement = null

  constructor: (@svgDocument, @selectionModel) ->
    @_setupNodeElement()
    @_setupLineElement()
    @_setupHandleElements()
    @hide()

  hide: ->
    @visible = false
    @lineElement.hide()
    @nodeElement.hide()
    @handleElements.hide()

  show: ->
    @visible = true
    @lineElement.front()
    @nodeElement.front().show()
    @handleElements.front()

    if @enableHandles
      @lineElement.show()
      @handleElements.show()
    else
      @lineElement.hide()
      @handleElements.hide()

  setEnableHandles: (@enableHandles) ->
    @show() if @visible

  setNode: (node) ->
    @_unbindNode(@node)
    @node = node
    @_bindNode(@node)
    @setEnableHandles(false)
    @render()

  render: =>
    return @hide() unless @node

    handleIn = @node.getAbsoluteHandleIn()
    handleOut = @node.getAbsoluteHandleOut()
    point = @node.point

    linePath = "M#{handleIn.x},#{handleIn.y}L#{point.x},#{point.y}L#{handleOut.x},#{handleOut.y}"
    @lineElement.attr(d: linePath)

    @handleElements.members[0].attr(cx: handleIn.x, cy: handleIn.y)
    @handleElements.members[1].attr(cx: handleOut.x, cy: handleOut.y)

    @nodeElement.attr(cx: point.x, cy: point.y)

    @show()

    # make sure the handlethe user is dragging is on top. could get in the
    # situation where the handle passed under the other, and it feels weird.
    @_draggingHandle.front() if @_draggingHandle

  onDraggingNode: (delta, event) =>
    @node.setPoint(@pointForEvent(event))
  onDraggingHandleIn: (delta, event) =>
    @node.setAbsoluteHandleIn(@pointForEvent(event))
  onDraggingHandleOut: (delta, event) =>
    @node.setAbsoluteHandleOut(@pointForEvent(event))

  pointForEvent: (event) ->
    {clientX, clientY} = event
    {top, left} = $(@svgDocument.node).offset()

    new Curve.Point(event.clientX - left, event.clientY - top)

  _bindNode: (node) ->
    return unless node
    node.on 'change', @render
  _unbindNode: (node) ->
    return unless node
    node.removeListener 'change', @render

  _setupNodeElement: ->
    @nodeElement = @svgDocument.circle(@nodeSize)
    @nodeElement.node.setAttribute('class', 'node-editor-node')

    @nodeElement.click (e) =>
      e.stopPropagation()
      @setEnableHandles(true)
      @selectionModel.setSelectedNode(@node)
      false

    @nodeElement.draggable()
    @nodeElement.dragstart = => @selectionModel.setSelectedNode(@node)
    @nodeElement.dragmove = @onDraggingNode
    @nodeElement.on 'mouseover', =>
      @nodeElement.attr('r': @nodeSize+2)
    @nodeElement.on 'mouseout', =>
      @nodeElement.attr('r': @nodeSize)

  _setupLineElement: ->
    @lineElement = @svgDocument.path('')
    @lineElement.node.setAttribute('class', 'node-editor-lines')

  _setupHandleElements: ->
    self = this

    @handleElements = @svgDocument.set()
    @handleElements.add(
      @svgDocument.circle(@handleSize),
      @svgDocument.circle(@handleSize)
    )
    @handleElements.members[0].node.setAttribute('class', 'node-editor-handle')
    @handleElements.members[1].node.setAttribute('class', 'node-editor-handle')

    @handleElements.click (e) =>
      e.stopPropagation()
      false

    onStartDraggingHandle = ->
      self._draggingHandle = this
    onStopDraggingHandle = ->
      self._draggingHandle = null

    @handleElements.members[0].draggable()
    @handleElements.members[0].dragmove = @onDraggingHandleIn
    @handleElements.members[0].dragstart = onStartDraggingHandle
    @handleElements.members[0].dragend = onStopDraggingHandle

    @handleElements.members[1].draggable()
    @handleElements.members[1].dragmove = @onDraggingHandleOut
    @handleElements.members[1].dragstart = onStartDraggingHandle
    @handleElements.members[1].dragend = onStopDraggingHandle

    # I hate this.
    find = (el) =>
      return @handleElements.members[0] if @handleElements.members[0].node == el
      @handleElements.members[1]

    @handleElements.on 'mouseover', ->
      el = find(this)
      el.front()
      el.attr('r': self.handleSize+2)
    @handleElements.on 'mouseout', ->
      el = find(this)
      el.attr('r': self.handleSize)

_ = window._ or require 'underscore'

EventEmitter = window.EventEmitter or require('events').EventEmitter

#
class Node extends EventEmitter
  constructor: (point, handleIn, handleOut, @isJoined=false) ->
    @setPoint(point)
    @setHandleIn(handleIn) if handleIn
    @setHandleOut(handleOut) if handleOut

  getAbsoluteHandleIn: ->
    if @handleIn
      @point.add(@handleIn)
    else
      @point
  getAbsoluteHandleOut: ->
    if @handleOut
      @point.add(@handleOut)
    else
      @point

  setAbsoluteHandleIn: (point) ->
    @setHandleIn(Point.create(point).subtract(@point))
  setAbsoluteHandleOut: (point) ->
    @setHandleOut(Point.create(point).subtract(@point))

  setPoint: (point) ->
    @set('point', Point.create(point))
  setHandleIn: (point) ->
    point = Point.create(point)
    @set('handleIn', point)
    @set('handleOut', new Curve.Point(0,0).subtract(point)) if @isJoined
  setHandleOut: (point) ->
    point = Point.create(point)
    @set('handleOut', point)
    @set('handleIn', new Curve.Point(0,0).subtract(point)) if @isJoined

  computeIsjoined: ->
    @isJoined = (not @handleIn and not @handleOut) or (@handleIn and @handleOut and Math.round(@handleIn.x) == Math.round(-@handleOut.x) and Math.round(@handleIn.y) == Math.round(-@handleOut.y))

  set: (attribute, value) ->
    old = @[attribute]
    @[attribute] = value

    event = "change:#{attribute}"
    eventArgs = {event, value, old}

    @emit event, this, eventArgs
    @emit 'change', this, eventArgs

Curve.Node = Node


#
class Curve.ObjectSelection
  constructor: (@svgDocument, @options={}) ->
    @options.class ?= 'object-selection'

  setObject: (object) ->
    @_unbindObject(@object)
    @object = object
    @_bindObject(@object)

    @path.remove() if @path
    @path = null
    if @object
      @path = @svgDocument.path('').front()
      @path.node.setAttribute('class', @options.class + ' invisible-to-hit-test')
      @render()

  render: =>
    @object.render(@path)

  _bindObject: (object) ->
    return unless object
    object.on 'change', @render

  _unbindObject: (object) ->
    return unless object
    object.removeListener 'change', @render

_ = window._ or require 'underscore'

[COMMAND, NUMBER] = ['COMMAND', 'NUMBER']

parsePath = (pathString) ->
  #console.log 'parsing', pathString
  tokens = lexPath(pathString)
  parseTokens(groupCommands(tokens))

# Parses the result of lexPath
parseTokens = (groupedCommands) ->
  result =
    subpaths: []

  # Just a move command? We dont care.
  return result if groupedCommands.length == 1 and groupedCommands[0].type in ['M', 'm']

  currentPoint = null # svg is stateful. Each command will set this.
  firstHandle = null

  currentSubpath = null
  addNewSubpath = (movePoint) ->
    node = new Node(movePoint)
    currentSubpath =
      closed: false
      nodes: [node]
    result.subpaths.push(currentSubpath)
    node

  slicePoint = (array, index) ->
    [array[index], array[index + 1]]

  makeAbsolute = (array) ->
    _.map array, (val, i) ->
      val + currentPoint[i % 2]

  for i in [0...groupedCommands.length]
    command = groupedCommands[i]
    switch command.type
      when 'M'
        currentPoint = command.parameters
        addNewSubpath(currentPoint)

      when 'L', 'l'
        params = command.parameters
        params = makeAbsolute(params) if command.type == 'l'

        currentPoint = slicePoint(params, 0)
        currentSubpath.nodes.push(new Node(currentPoint))

      when 'H', 'h'
        params = command.parameters
        params = makeAbsolute(params) if command.type == 'h'

        currentPoint = [params[0], currentPoint[1]]
        currentSubpath.nodes.push(new Node(currentPoint))

      when 'V', 'v'
        params = command.parameters
        if command.type == 'v'
          params = makeAbsolute([0, params[0]])
          params = params.slice(1)

        currentPoint = [currentPoint[0], params[0]]
        currentSubpath.nodes.push(new Node(currentPoint))

      when 'C', 'c'
        params = command.parameters
        params = makeAbsolute(params) if command.type == 'c'

        currentPoint = slicePoint(params, 4)
        handleIn = slicePoint(params, 2)
        handleOut = slicePoint(params, 0)

        firstNode = currentSubpath.nodes[0]
        lastNode = currentSubpath.nodes[currentSubpath.nodes.length - 1]
        lastNode.setAbsoluteHandleOut(handleOut)

        nextCommand = groupedCommands[i + 1]
        if nextCommand and nextCommand.type in ['z', 'Z'] and firstNode and firstNode.point.equals(currentPoint)
          firstNode.setAbsoluteHandleIn(handleIn)
        else
          curveNode = new Node(currentPoint)
          curveNode.setAbsoluteHandleIn(handleIn)
          currentSubpath.nodes.push(curveNode)

      when 'Z', 'z'
        currentSubpath.closed = true

  for subpath in result.subpaths
    node.computeIsjoined() for node in subpath.nodes

  result

# Returns a list of svg commands with their parameters.
groupCommands = (pathTokens) ->
  console.log 'grouping tokens', pathTokens
  commands = []
  for i in [0...pathTokens.length]
    token = pathTokens[i]

    continue unless token.type == COMMAND

    command =
      type: token.string
      parameters: []

    while nextToken = pathTokens[i+1]
      if nextToken.type == NUMBER
        command.parameters.push(parseFloat(nextToken.string))
        i++
      else
        break

    console.log command.type, command
    commands.push(command)

  commands

# Breaks pathString into tokens
lexPath = (pathString) ->
  numberMatch = '-0123456789.'
  separatorMatch = ' ,\n\t'

  tokens = []
  currentToken = null

  saveCurrentTokenWhenDifferentThan = (command) ->
    saveCurrentToken() if currentToken and currentToken.type != command

  saveCurrentToken = ->
    return unless currentToken
    currentToken.string = currentToken.string.join('') if currentToken.string.join
    tokens.push(currentToken)
    currentToken = null

  for ch in pathString
    if numberMatch.indexOf(ch) > -1
      saveCurrentTokenWhenDifferentThan(NUMBER)
      saveCurrentToken() if ch == '-'

      currentToken = {type: NUMBER, string: []} unless currentToken
      currentToken.string.push(ch)

    else if separatorMatch.indexOf(ch) > -1
      saveCurrentToken()

    else
      saveCurrentToken()
      tokens.push(type: COMMAND, string: ch)

  saveCurrentToken()
  tokens

Curve.PathParser = {lexPath, parsePath, groupCommands, parseTokens}

_ = window._ or require 'underscore'

EventEmitter = window.EventEmitter or require('events').EventEmitter

attrs = {fill: '#eee', stroke: 'none'}

IDS = 0
#
class Path extends EventEmitter
  constructor: (@svgDocument, {svgEl}={}) ->
    @id = IDS++
    @subpaths = []
    @_setupSVGObject(svgEl)

  toString: ->
    "Path #{@id} #{@toPathString()}"
  toPathString: ->
    (subpath.toPathString() for subpath in @subpaths).join(' ')

  getNodes: ->
    _.flatten(subpath.getNodes() for subpath in @subpaths, true)

  # FIXME: the currentSubpath thing will probably leave. depends on how insert
  # nodes works in interface.
  addNode: (node) ->
    @_addCurrentSubpathIfNotPresent()
    @currentSubpath.addNode(node)
  insertNode: (node, index) ->
    @_addCurrentSubpathIfNotPresent()
    @currentSubpath.insertNode(node, index)
  close: ->
    @_addCurrentSubpathIfNotPresent()
    @currentSubpath.close()
  _addCurrentSubpathIfNotPresent: ->
    @currentSubpath = @_createSubpath() unless @currentSubpath
  # End currentSubpath stuff

  addSubpath: (subpath) ->
    @subpaths.push(subpath)
    @_bindSubpath(subpath)

    args =
      event: 'add:subpath'
      value: subpath
    @emit(args.event, this, args)
    @emit('change', this, args)

    subpath

  render: (svgEl=@svgEl) ->
    pathStr = @toPathString()
    svgEl.attr(d: pathStr) if pathStr

  onSubpathEvent: (subpath, eventArgs) =>
    @emit eventArgs.event, this, _.extend({subpath}, eventArgs)

  onSubpathChange: (subpath, eventArgs) =>
    @render()
    @emit 'change', this, _.extend({subpath}, eventArgs)

  _createSubpath: (args) ->
    @addSubpath(new Subpath(_.extend({path: this}, args)))

  _bindSubpath: (subpath) ->
    return unless subpath
    subpath.on 'change', @onSubpathChange
    subpath.on 'close', @onSubpathEvent
    subpath.on 'insert:node', @onSubpathEvent
    subpath.on 'replace:nodes', @onSubpathEvent

  _unbindSubpath: (subpath) ->
    return unless subpath
    subpath.off 'change', @onSubpathChange
    subpath.off 'close', @onSubpathEvent
    subpath.off 'insert:node', @onSubpathEvent
    subpath.off 'replace:nodes', @onSubpathEvent

  _parseFromPathString: (pathString) ->
    return unless pathString

    parsedPath = Curve.PathParser.parsePath(pathString)
    @_createSubpath(parsedSubpath) for parsedSubpath in parsedPath.subpaths

    @currentSubpath = _.last(@subpaths)

    null

  _setupSVGObject: (@svgEl) ->
    @svgEl = @svgDocument.path().attr(attrs) unless @svgEl
    Curve.Utils.setObjectOnNode(@svgEl.node, this)
    @_parseFromPathString(@svgEl.attr('d'))

Curve.Path = Path

#
class Curve.PenTool
  currentObject: null
  currentNode: null

  constructor: (@svgDocument, {@selectionModel, @selectionView}={}) ->

  activate: ->
    @svgDocument.on 'mousedown', @onMouseDown
    @svgDocument.on 'mousemove', @onMouseMove
    @svgDocument.on 'mouseup', @onMouseUp

  deactivate: ->
    @svgDocument.off 'mousedown', @onMouseDown
    @svgDocument.off 'mousemove', @onMouseMove
    @svgDocument.off 'mouseup', @onMouseUp

  onMouseDown: (e) =>
    makeNode = =>
      @currentNode = new Curve.Node([e.clientX, e.clientY], [0, 0], [0, 0])
      @currentObject.addNode(@currentNode)
      @selectionModel.setSelectedNode(@currentNode)

    if @currentObject
      if @selectionView.nodeEditors.length and e.target == @selectionView.nodeEditors[0].nodeElement.node
        @currentObject.close()
        @currentObject = null
      else
        makeNode()
    else
      @currentObject = new Curve.Path(@svgDocument)
      @selectionModel.setSelected(@currentObject)
      makeNode()

  onMouseMove: (e) =>
    @currentNode.setAbsoluteHandleOut([e.clientX, e.clientY]) if @currentNode

  onMouseUp: (e) =>
    @currentNode = null

_ = window._ or require 'underscore'

#
class Point
  @create: (x, y) ->
    return x if x instanceof Point
    new Point(x, y)

  constructor: (x, y) ->
    @set(x, y)

  set: (@x, @y) ->
    [@x, @y] = @x if _.isArray(@x)

  add: (other) ->
    other = Point.create(other)
    new Point(@x + other.x, @y + other.y)

  subtract: (other) ->
    other = Point.create(other)
    new Point(@x - other.x, @y - other.y)

  toArray: ->
    [@x, @y]

  equals: (other) ->
    other = Point.create(other)
    other.x == @x and other.y == @y

Curve.Point = Point

$ = window.jQuery or require 'underscore'

class Curve.PointerTool
  constructor: (@svgDocument, {@selectionModel, @selectionView}={}) ->
    @_evrect = svgDocument.node.createSVGRect();
    @_evrect.width = @_evrect.height = 1;

  activate: ->
    @svgDocument.on 'click', @onClick
    @svgDocument.on 'mousemove', @onMouseMove

  deactivate: ->
    @svgDocument.off 'click', @onClick
    @svgDocument.off 'mousemove', @onMouseMove

  onClick: (e) =>
    # obj = @_hitWithIntersectionList(e)
    obj = @_hitWithTarget(e)
    @selectionModel.setSelected(obj)
    return false if obj

  onMouseMove: (e) =>
    # @selectionModel.setPreselected(@_hitWithIntersectionList(e))
    @selectionModel.setPreselected(@_hitWithTarget(e))

  _hitWithTarget: (e) ->
    obj = null
    obj = Curve.Utils.getObjectFromNode(e.target) if e.target != @svgDocument.node
    obj

  _hitWithIntersectionList: (e) ->
    {left, top} = $(@svgDocument.node).offset()
    @_evrect.x = e.clientX - left
    @_evrect.y = e.clientY - top
    nodes = @svgDocument.node.getIntersectionList(@_evrect, null)

    obj = null
    if nodes.length
      for i in [nodes.length-1..0]
        clas = nodes[i].getAttribute('class')
        continue if clas and clas.indexOf('invisible-to-hit-test') > -1
        obj = Curve.Utils.getObjectFromNode(nodes[i])
        break

    obj

EventEmitter = window.EventEmitter or require('events').EventEmitter

#
class Curve.SelectionModel extends EventEmitter
  constructor: ->
    @preselected = null
    @selected = null
    @selectedNode = null

  setPreselected: (preselected) ->
    return if preselected == @preselected
    return if preselected == @selected
    old = @preselected
    @preselected = preselected
    @emit 'change:preselected', object: @preselected, old: old

  setSelected: (selected) ->
    return if selected == @selected
    old = @selected
    @selected = selected
    @emit 'change:selected', object: @selected, old: old

  setSelectedNode: (selectedNode) ->
    return if selectedNode == @selectedNode
    old = @selectedNode
    @selectedNode = selectedNode
    @emit 'change:selectedNode', node: @selectedNode, old: old

  clearSelected: ->
    @setSelected(null)
  clearPreselected: ->
    @setPreselected(null)
  clearSelectedNode: ->
    @setSelectedNode(null)


#
class Curve.SelectionView
  nodeSize: 5

  constructor: (@svgDocument, @model) ->
    @path = null
    @nodeEditors = []
    @_nodeEditorStash = []

    @objectSelection = new Curve.ObjectSelection(@svgDocument)
    @objectPreselection = new Curve.ObjectSelection(@svgDocument, class: 'object-preselection')

    @model.on 'change:selected', @onChangeSelected
    @model.on 'change:preselected', @onChangePreselected
    @model.on 'change:selectedNode', @onChangeSelectedNode

  onChangeSelected: ({object, old}) =>
    @_unbindFromObject(old)
    @_bindToObject(object)
    @setSelectedObject(object)
  onChangePreselected: ({object}) =>
    @objectPreselection.setObject(object)
  onChangeSelectedNode: ({node, old}) =>
    nodeEditor = @_findNodeEditorForNode(old)
    nodeEditor.setEnableHandles(false) if nodeEditor

    nodeEditor = @_findNodeEditorForNode(node)
    nodeEditor.setEnableHandles(true) if nodeEditor

  setSelectedObject: (object) ->
    @objectSelection.setObject(object)
    @_createNodeEditors(object)

  onInsertNode: (object, {value, index}={}) =>
    @_addNodeEditor(value)
    null # Force null. otherwise _insertNodeEditor returns true and tells event emitter 'once'. Ugh

  _bindToObject: (object) ->
    return unless object
    object.on 'insert:node', @onInsertNode

  _unbindFromObject: (object) ->
    return unless object
    object.removeListener 'insert:node', @onInsertNode

  _createNodeEditors: (object) ->
    @_nodeEditorStash = @nodeEditors
    @nodeEditors = []

    if object
      nodes = object.getNodes()
      @_addNodeEditor(node) for node in nodes

    for nodeEditor in @_nodeEditorStash
      nodeEditor.setNode(null)

  _addNodeEditor: (node) ->
    return false unless node

    nodeEditor = if @_nodeEditorStash.length
      @_nodeEditorStash.pop()
    else
      new Curve.NodeEditor(@svgDocument, @model)

    nodeEditor.setNode(node)
    @nodeEditors.push(nodeEditor)
    true

  _findNodeEditorForNode: (node) ->
    for nodeEditor in @nodeEditors
      return nodeEditor if nodeEditor.node == node
    null

_ = window._ or require 'underscore'

EventEmitter = window.EventEmitter or require('events').EventEmitter

# Subpath handles a single path from move node -> close node.
#
# Svg paths can have many subpaths like this:
#
#   M50,50L20,30Z  M4,5L2,3Z
#
# Each one of these will be represented by this Subpath class.
class Subpath extends EventEmitter
  constructor: ({@path, @closed, nodes}={}) ->
    @nodes = []
    @setNodes(nodes)
    @closed = !!@closed

  toString: ->
    "Subpath #{@toPathString()}"

  toPathString: ->
    path = ''
    lastPoint = null

    makeCurve = (fromNode, toNode) ->
      curve = []
      curve = curve.concat(fromNode.getAbsoluteHandleOut().toArray())
      curve = curve.concat(toNode.getAbsoluteHandleIn().toArray())
      curve = curve.concat(toNode.point.toArray())
      'C' + curve.join(',')

    closePath = (firstNode, lastNode)->
      return '' unless firstNode and lastNode
      closingPath = ''
      closingPath += makeCurve(lastNode, firstNode) if lastNode.handleOut or firstNode.handleIn
      closingPath += 'Z'

    for node in @nodes
      if path
        path += makeCurve(lastNode, node)
      else
        path += 'M' + node.point.toArray().join(',')

      lastNode = node

    path += closePath(@nodes[0], @nodes[@nodes.length-1]) if @closed
    path

  getNodes: -> @nodes

  setNodes: (nodes) ->
    return unless nodes and _.isArray(nodes)

    @_unbindNode(node) for node in @nodes
    @_bindNode(node) for node in nodes

    @nodes = nodes

    args =
      event: 'replace:nodes'
      value: @nodes
    @emit(args.event, this, args)
    @emit('change', this, args)

  addNode: (node) ->
    @insertNode(node, @nodes.length)

  insertNode: (node, index) ->
    @_bindNode(node)
    @nodes.splice(index, 0, node)

    args =
      event: 'insert:node'
      index: index
      value: node
    @emit('insert:node', this, args)
    @emit('change', this, args)

  close: ->
    @closed = true

    args = event: 'close'
    @emit('close', this, args)
    @emit('change', this, args)

  onNodeChange: (node, eventArgs) =>
    index = @_findNodeIndex(node)
    @emit 'change', this, _.extend({index}, eventArgs)

  _bindNode: (node) ->
    node.on 'change', @onNodeChange
  _unbindNode: (node) ->
    node.off 'change', @onNodeChange

  _findNodeIndex: (node) ->
    for i in [0...@nodes.length]
      return i if @nodes[i] == node
    -1

Curve.Subpath = Subpath

SVG = window.SVG or require('./vendor/svg').SVG

class SvgDocument
  constructor: (svgContent, rootNode) ->
    @svgDocument = SVG(rootNode)
    Curve.import(@svgDocument, svgContent)

    @selectionModel = new Curve.SelectionModel()
    @selectionView = new Curve.SelectionView(@svgDocument, @selectionModel)

    @tool = new Curve.PointerTool(@svgDocument, {@selectionModel, @selectionView})
    @tool.activate()

Curve.SvgDocument = SvgDocument

Curve.Examples =
  cloud: '''<svg height="1024" width="1024" xmlns="http://www.w3.org/2000/svg"><path d="M512,384L320,576h128v320h128V576h128L512,384z M832,320c-8.75,0-17.125,1.406-25.625,2.562
	C757.625,208.188,644.125,128,512,128c-132.156,0-245.562,80.188-294.406,194.562C209.156,321.406,200.781,320,192,320
	C85.938,320,0,406,0,512c0,106.062,85.938,192,192,192c20.531,0,39.875-4.25,58.375-10.438
	C284.469,731.375,331.312,756.75,384,764.5v-65.25c-49.844-10.375-91.594-42.812-112.625-87.75C249.531,629,222.219,640,192,640
	c-70.656,0-128-57.375-128-128c0-70.656,57.344-128,128-128c25.281,0,48.625,7.562,68.406,20.156
	C281.344,283.781,385.594,192,512,192c126.5,0,229.75,92.219,250.5,212.75c20-13,43.875-20.75,69.5-20.75
	c70.625,0,128,57.344,128,128c0,70.625-57.375,128-128,128c-10.25,0-20-1.5-29.625-3.75C773.438,677.125,725.938,704,672,704
	c-11.062,0-21.625-1.625-32-4v64.938c10.438,1.688,21.062,3.062,32,3.062c61.188,0,116.5-24.688,157-64.438c1,0,1.875,0.438,3,0.438
	c106.062,0,192-85.938,192-192C1024,406,938.062,320,832,320z"/></svg>'''

  heckert: '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <svg
       xmlns:svg="http://www.w3.org/2000/svg"
       xmlns="http://www.w3.org/2000/svg"
       version="1.0"
       width="534.64301"
       height="522.526"
       viewBox="0 0 534.643 522.526"
       id="svg3097"
       xml:space="preserve"><defs
       id="defs3105" />

      <g style="fill:#ffffff;fill-opacity:1" id="Layer_1">
        <g style="fill:#ffffff;fill-opacity:1" id="g3100">
          <path
       d="M 101.454,311.936 C 98.863,316.582 92.793,317.323 89.959,316.387 C 85.238,314.827 79.204,313.745 73.359,317.91 C 67.514,322.074 61.202,318.925 62.309,311.334 C 63.416,303.744 66.158,296.983 73.436,292.796 C 89.331,283.652 78.284,277.288 87.008,268.111 C 95.749,258.916 93.818,256.102 93.528,243.614 C 63.985,239.176 47.241,230.661 28.544,207.301 C 9.847,183.94 2.599,164.711 0.661,135.423 C -1.277,106.135 0.403,87.154 13.057,62.843 C 25.711,38.532 39.034,26.829 62.122,14.69 C 85.21,2.553 107.832,-0.354 128.742,0 C 149.652,0.353 163.585,1.885 175.4,8.626 C 187.214,15.367 198.022,23.85 204.912,23.911 C 211.803,23.972 216.494,22.167 219.843,19.601 C 220.737,42.304 200.304,44.276 182.024,44.756 C 163.743,45.235 152.51,37.673 135.673,40.486 C 118.836,43.299 91.269,50.961 77.84,74.336 C 64.411,97.711 63.953,105.974 65.069,125.576 C 66.185,145.179 83.057,159.804 92.581,159.963 C 102.104,160.122 104.23,157.364 112.566,151.927 C 120.903,146.489 163.462,93.805 177.984,81.971 C 192.507,70.137 206.838,66.483 222.312,66.293 C 237.786,66.103 241.74,66.628 254.22,71.743 C 266.7,76.857 274.369,86.276 284.431,92.034 C 289.574,89.007 292.769,84.487 297.488,81.038 C 314.365,68.703 323.134,65.379 343.193,67.331 C 354.722,68.453 369.259,75.039 377.933,82.581 C 393.378,96.01 406.138,114.706 416.449,128.909 C 424.478,139.97 433.926,153.204 447.414,157.341 C 462.141,161.856 473.223,142.782 474.85,132.202 C 475.772,126.207 476.975,120.953 476.985,114.355 C 476.995,107.756 476.321,99.748 474.419,92.871 C 472.517,85.994 469.259,79.151 465.731,73.477 C 459.989,64.242 450.594,54.578 440.819,49.606 C 435.333,46.816 422.426,41.743 414.29,41.565 C 404.321,41.349 396.726,44.698 387.509,45.326 C 376.353,46.087 356.425,48.595 347.679,39.976 C 342.113,34.491 341.413,30.832 340.462,23.68 C 342.921,25.706 346.36,27.038 349.421,27.297 C 356.407,27.887 362.948,22.183 368.587,18.878 C 373.232,16.155 379.81,11.289 385.911,8.83 C 401.587,2.51 420.843,2.692 437.391,4.385 C 450.655,5.741 467.852,11.642 479.485,18.225 C 491.173,24.837 502.436,35.986 510.686,46.496 C 521.065,59.72 526.739,71.066 530.498,87.559 C 535.303,108.621 536.635,140.261 530.826,161.028 C 526.248,177.393 511.047,202.532 498.107,214.855 C 485.345,227.01 470.609,232.877 453.851,236.086 C 454.507,239.468 454.615,242.622 455.482,245.395 C 456.714,249.331 459.07,253.719 463.91,252.331 C 465.84,251.778 466.873,251.299 469.418,253.525 C 471.961,255.751 470.637,264.35 463.48,268.209 C 459.851,270.166 456.021,270.591 450.209,270.707 C 444.397,270.823 435.326,270.848 429.016,269.743 C 422.707,268.639 418.938,263.632 411.95,262.848 C 401.151,261.64 392.882,253.838 384.223,248.258 C 380.61,245.929 379.391,245.905 377.309,244.728 C 378.434,248.172 379.934,251.749 380.682,255.06 C 381.432,258.371 381.112,261.438 381.51,264.088 C 381.906,266.736 382.641,268.795 383.069,270.943 C 384.799,272.49 385.352,274.843 388.258,275.583 C 391.166,276.322 395.719,275.171 398.694,274.771 C 401.669,274.371 403.663,272.75 405.997,273.194 C 408.333,273.637 410.546,275.309 412.503,276.876 C 414.46,278.443 416.142,278.672 417.726,282.582 C 419.31,286.492 420.763,294.499 420.98,299.851 C 421.197,305.203 420.597,310.034 419.011,314.281 C 417.425,318.528 416.031,320.411 411.736,324.617 C 407.441,328.824 400.447,334.997 393.468,339.297 C 394.753,341.2 395.323,342.942 397.327,345.007 C 399.331,347.073 403.509,349.388 405.368,351.567 C 407.225,353.746 408.167,355.309 408.194,357.753 C 408.223,360.196 408.104,363.372 406.12,366.036 C 401.179,372.669 395.335,373.857 388.229,376.977 C 389.424,384.439 390.399,389.77 388.672,397.221 C 387.967,400.257 386.401,407.141 382.656,408.907 C 378.91,410.673 371.687,409.818 367.115,410.544 C 362.543,411.271 359.984,411.961 356.42,412.669 C 354.254,415.8 351.029,419.255 349.924,422.061 C 348.817,424.868 349.151,425.874 350.08,428.74 C 351.009,431.606 354.172,435.779 355.068,439.135 C 355.964,442.491 356.138,446.104 355.302,449.469 C 354.464,452.834 353.031,455.276 350.163,458.264 C 347.296,461.253 341.655,463.6 338.845,466.022 C 336.033,468.445 333.234,468.736 334.001,472.745 C 335.056,478.251 343.101,487.181 348.921,489.307 C 352.409,490.582 357.091,490.18 361.327,488.392 C 361.04,493.095 356.97,496.265 354.311,499.388 C 361.512,497.329 368.495,493.387 373.325,488.162 C 371.827,492.7 366.673,499.985 358.964,506.382 C 351.255,512.779 351.302,511.47 347.47,514.015 C 354.462,515.42 360.964,515.04 366.38,514.067 C 363.411,515.704 358.544,518.006 352.097,518.683 C 345.65,519.359 341.675,518.881 335.865,517.47 C 330.054,516.058 324.75,510.776 317.709,507.135 C 318.395,509.747 318.883,512.888 321.844,515.574 C 324.805,518.26 329.285,519.626 334.047,521.949 C 327.985,521.261 321.615,521.053 315.658,519.74 C 311.248,518.767 308.285,517.735 305.058,516.137 C 301.833,514.539 299.343,512.208 296.486,510.244 C 297.855,512.859 298.261,515.935 300.591,518.091 C 302.921,520.247 306.708,521.05 309.771,522.531 C 306.576,522.461 303.503,523.154 300.191,522.321 C 296.877,521.488 293.769,520.179 290.324,517.641 C 286.879,515.103 283.326,511.978 280.386,508.783 C 277.448,505.588 273.82,501.446 272.722,498.5 C 271.622,495.553 273.382,493.492 273.712,490.991 C 271.683,492.324 269.187,493.058 267.628,494.993 C 266.069,496.928 264.687,498.695 265.377,502.068 C 266.068,505.441 269.181,509.564 271.382,513.316 C 264.814,507.945 261.146,505.877 259.583,499.398 C 258.12,493.332 261.905,487.826 264.782,483.239 C 266.211,480.961 268.349,478.841 269.685,476.642 C 266.718,473.739 263.327,471.244 260.784,467.933 C 258.242,464.623 257.174,460.143 254.579,456.976 C 251.983,453.808 248.491,451.803 245.45,449.22 C 248.123,454.962 252.516,462.005 253.47,466.449 C 254.423,470.893 252.401,473.613 250.824,476.012 C 249.246,478.411 246.7,478.946 244.285,480.42 C 241.87,481.895 238.114,480.732 236.675,482.921 C 235.237,485.109 234.851,488.401 236.226,490.569 L 241.866,499.471 C 239.788,498.422 236.208,495.371 234.594,493.207 C 232.98,491.043 230.504,489.044 230.165,486.118 C 229.826,483.193 229.661,480.654 231.556,478.048 C 233.452,475.443 238.642,474.571 240.965,472.568 C 243.288,470.565 244.591,469.261 244.458,466.672 C 244.326,464.083 241.797,462.231 239.623,460.599 C 232.986,455.621 224.472,451.034 218.836,445.034 C 215.652,441.644 214.124,438.907 213.484,436.568 C 212.845,434.23 213.521,432.406 215.103,429.53 C 216.685,426.653 222.11,422.812 222.77,419.687 C 223.429,416.563 220.689,415.892 218.216,414.79 C 215.743,413.688 211.046,415.355 208.752,413.438 C 206.459,411.521 209.426,407.493 206.841,405.284 C 204.257,403.075 198.342,404.308 195.289,401.932 C 192.236,399.555 190.974,396.605 189.922,393.157 C 188.87,389.709 188.751,385.932 189.464,383.435 C 190.177,380.938 192.319,380.501 193.611,379.207 C 194.903,377.913 196.024,376.84 194.302,374.91 C 192.58,372.981 186.937,375.018 183.693,372.541 C 180.449,370.064 182.435,364.131 180.141,361.63 C 177.848,359.129 173.732,360.108 171.56,359.309 C 169.389,358.51 168.537,361.329 167.205,356.871 C 165.873,352.412 165.837,339.121 164.045,334.161 C 162.253,329.201 158.734,333.826 157.1,328.896 C 155.466,323.967 157.015,316.084 156.279,308.639 L 152.944,288.382 C 141.31,296.197 104.628,306.247 101.454,311.936 z "
       style="fill:#ffffff;fill-opacity:1;fill-rule:evenodd"
       id="path3102" />
        </g>
      </g>
      <g transform="translate(1.443171e-2,-0.209173)" id="g4915">
        <g id="g4906">
            <path
         d="M 112.993,304.372 C 109.359,304.619 104.628,306.247 101.454,311.936 C 98.863,316.582 92.793,317.323 89.959,316.387 C 85.238,314.827 79.204,313.745 73.359,317.91 C 67.514,322.074 61.202,318.925 62.309,311.334 C 63.416,303.744 66.158,296.983 73.436,292.796 C 89.331,283.652 78.284,277.288 87.008,268.111 C 95.749,258.916 93.818,256.102 93.528,243.614 C 63.985,239.176 47.241,230.661 28.544,207.301 C 9.847,183.94 2.599,164.711 0.661,135.423 C -1.277,106.135 0.403,87.154 13.057,62.843 C 25.711,38.532 39.034,26.829 62.122,14.69 C 85.21,2.553 107.832,-0.354 128.742,0 C 149.652,0.353 163.585,1.885 175.4,8.626 C 187.214,15.367 198.022,23.85 204.912,23.911 C 211.803,23.972 216.494,22.167 219.843,19.601 C 220.737,42.304 200.304,44.276 182.024,44.756 C 163.743,45.235 152.51,37.673 135.673,40.486 C 118.836,43.299 91.269,50.961 77.84,74.336 C 64.411,97.711 63.953,105.974 65.069,125.576 C 66.185,145.179 83.057,159.804 92.581,159.963 C 102.104,160.122 104.23,157.364 112.566,151.927 C 120.903,146.489 163.462,93.805 177.984,81.971 C 192.507,70.137 206.838,66.483 222.312,66.293 C 237.786,66.103 241.74,66.628 254.22,71.743 C 266.7,76.857 274.369,86.276 284.431,92.034 C 289.574,89.007 292.769,84.487 297.488,81.038 C 314.365,68.703 323.134,65.379 343.193,67.331 C 354.722,68.453 369.259,75.039 377.933,82.581 C 393.378,96.01 406.138,114.706 416.449,128.909 C 424.478,139.97 433.926,153.204 447.414,157.341 C 462.141,161.856 473.223,142.782 474.85,132.202 C 475.772,126.207 476.975,120.953 476.985,114.355 C 476.995,107.756 476.321,99.748 474.419,92.871 C 472.517,85.994 469.259,79.151 465.731,73.477 C 459.989,64.242 450.594,54.578 440.819,49.606 C 435.333,46.816 422.426,41.743 414.29,41.565 C 404.321,41.349 396.726,44.698 387.509,45.326 C 376.353,46.087 356.425,48.595 347.679,39.976 C 342.113,34.491 341.413,30.832 340.462,23.68 C 342.921,25.706 346.36,27.038 349.421,27.297 C 356.407,27.887 362.948,22.183 368.587,18.878 C 373.232,16.155 379.81,11.289 385.911,8.83 C 401.587,2.51 420.843,2.692 437.391,4.385 C 450.655,5.741 467.852,11.642 479.485,18.225 C 491.173,24.837 502.436,35.986 510.686,46.496 C 521.065,59.72 526.739,71.066 530.498,87.559 C 535.303,108.621 536.635,140.261 530.826,161.028 C 526.248,177.393 511.047,202.532 498.107,214.855 C 485.345,227.01 470.609,232.877 453.851,236.086 C 454.507,239.468 454.615,242.622 455.482,245.395 C 456.714,249.331 459.07,253.719 463.91,252.331 C 465.84,251.778 466.873,251.299 469.418,253.525 C 471.961,255.751 470.637,264.35 463.48,268.209 C 459.851,270.166 456.021,270.591 450.209,270.707 C 444.397,270.823 435.326,270.848 429.016,269.743 C 422.707,268.639 418.938,263.632 411.95,262.848 C 401.151,261.64 392.882,253.838 384.223,248.258 C 380.61,245.929 379.391,245.905 377.309,244.728 C 378.434,248.172 379.934,251.749 380.682,255.06 C 381.432,258.371 381.112,261.438 381.51,264.088 C 381.906,266.736 382.641,268.795 383.069,270.943 C 384.799,272.49 385.352,274.843 388.258,275.583 C 391.166,276.322 395.719,275.171 398.694,274.771 C 401.669,274.371 403.663,272.75 405.997,273.194 C 408.333,273.637 410.546,275.309 412.503,276.876 C 414.46,278.443 416.142,278.672 417.726,282.582 C 419.31,286.492 420.763,294.499 420.98,299.851 C 421.197,305.203 420.597,310.034 419.011,314.281 C 417.425,318.528 416.031,320.411 411.736,324.617 C 407.441,328.824 400.447,334.997 393.468,339.297 C 394.753,341.2 395.323,342.942 397.327,345.007 C 399.331,347.073 403.509,349.388 405.368,351.567 C 407.225,353.746 408.167,355.309 408.194,357.753 C 408.223,360.196 408.104,363.372 406.12,366.036 C 401.179,372.669 395.335,373.857 388.229,376.977 C 389.424,384.439 390.399,389.77 388.672,397.221 C 387.967,400.257 386.401,407.141 382.656,408.907 C 378.91,410.673 371.687,409.818 367.115,410.544 C 362.543,411.271 359.984,411.961 356.42,412.669 C 354.254,415.8 351.029,419.255 349.924,422.061 C 348.817,424.868 349.151,425.874 350.08,428.74 C 351.009,431.606 354.172,435.779 355.068,439.135 C 355.964,442.491 356.138,446.104 355.302,449.469 C 354.464,452.834 353.031,455.276 350.163,458.264 C 347.296,461.253 341.655,463.6 338.845,466.022 C 336.033,468.445 333.234,468.736 334.001,472.745 C 335.056,478.251 343.101,487.181 348.921,489.307 C 352.409,490.582 357.091,490.18 361.327,488.392 C 361.04,493.095 356.97,496.265 354.311,499.388 C 361.512,497.329 368.495,493.387 373.325,488.162 C 371.827,492.7 366.673,499.985 358.964,506.382 C 351.255,512.779 351.302,511.47 347.47,514.015 C 354.462,515.42 360.964,515.04 366.38,514.067 C 363.411,515.704 358.544,518.006 352.097,518.683 C 345.65,519.359 341.675,518.881 335.865,517.47 C 330.054,516.058 324.75,510.776 317.709,507.135 C 318.395,509.747 318.883,512.888 321.844,515.574 C 324.805,518.26 329.285,519.626 334.047,521.949 C 327.985,521.261 321.615,521.053 315.658,519.74 C 311.248,518.767 308.285,517.735 305.058,516.137 C 301.833,514.539 299.343,512.208 296.486,510.244 C 297.855,512.859 298.261,515.935 300.591,518.091 C 302.921,520.247 306.708,521.05 309.771,522.531 C 306.576,522.461 303.503,523.154 300.191,522.321 C 296.877,521.488 293.769,520.179 290.324,517.641 C 286.879,515.103 283.326,511.978 280.386,508.783 C 277.448,505.588 273.82,501.446 272.722,498.5 C 271.622,495.553 273.382,493.492 273.712,490.991 C 271.683,492.324 269.187,493.058 267.628,494.993 C 266.069,496.928 264.687,498.695 265.377,502.068 C 266.068,505.441 269.181,509.564 271.382,513.316 C 264.814,507.945 261.146,505.877 259.583,499.398 C 258.12,493.332 261.905,487.826 264.782,483.239 C 266.211,480.961 268.349,478.841 269.685,476.642 C 266.718,473.739 263.327,471.244 260.784,467.933 C 258.242,464.623 257.174,460.143 254.579,456.976 C 251.983,453.808 248.491,451.803 245.45,449.22 C 248.123,454.962 252.516,462.005 253.47,466.449 C 254.423,470.893 252.401,473.613 250.824,476.012 C 249.246,478.411 246.7,478.946 244.285,480.42 C 241.87,481.895 238.114,480.732 236.675,482.921 C 235.237,485.109 234.851,488.401 236.226,490.569 L 241.866,499.471 C 239.788,498.422 236.208,495.371 234.594,493.207 C 232.98,491.043 230.504,489.044 230.165,486.118 C 229.826,483.193 229.661,480.654 231.556,478.048 C 233.452,475.443 238.642,474.571 240.965,472.568 C 243.288,470.565 244.591,469.261 244.458,466.672 C 244.326,464.083 241.797,462.231 239.623,460.599 C 232.986,455.621 224.472,451.034 218.836,445.034 C 215.652,441.644 214.124,438.907 213.484,436.568 C 212.845,434.23 213.521,432.406 215.103,429.53 C 216.685,426.653 222.11,422.812 222.77,419.687 C 223.429,416.563 220.689,415.892 218.216,414.79 C 215.743,413.688 211.046,415.355 208.752,413.438 C 206.459,411.521 209.426,407.493 206.841,405.284 C 204.257,403.075 198.342,404.308 195.289,401.932 C 192.236,399.555 190.974,396.605 189.922,393.157 C 188.87,389.709 188.751,385.932 189.464,383.435 C 190.177,380.938 192.319,380.501 193.611,379.207 C 194.903,377.913 196.024,376.84 194.302,374.91 C 192.58,372.981 186.937,375.018 183.693,372.541 C 180.449,370.064 182.435,364.131 180.141,361.63 C 177.848,359.129 173.732,360.108 171.56,359.309 C 169.389,358.51 168.537,361.329 167.205,356.871 C 165.873,352.412 165.837,339.121 164.045,334.161 C 162.253,329.201 158.734,333.826 157.1,328.896 C 155.466,323.967 157.015,316.084 156.279,308.639 L 152.944,288.382 C 141.31,296.197 133.63,298.651 121.131,300.859 C 120.088,331.441 117.215,349.45 127.595,383.379 C 137.975,417.307 158.982,437.303 187.321,466.028 C 149.926,438.012 132.073,415.236 120.899,386.058 C 109.723,356.876 111.869,332.472 112.993,304.372 z M 311.701,292.08 C 314.578,292.209 318.074,292.939 320.094,294.251 C 322.115,295.563 324.26,296.635 326.094,298.502 C 330.67,303.162 334.102,308.782 335.619,315.24 C 336.586,319.357 336.73,324.637 337.082,329.471 C 335.697,325.003 334.766,320.344 332.793,316.341 C 329.682,310.029 324.397,303.868 317.834,301.031 C 315.668,300.093 314.223,300.267 313.031,300.433 C 313.564,301.328 314.457,302.078 314.496,303.389 C 314.535,304.7 314.242,307.265 312.019,308.343 C 308.435,310.082 304.451,308.859 301.683,306.412 C 298.892,303.946 297.941,299.774 299.402,296.189 C 301.143,291.917 307.777,291.906 311.701,292.08 z M 275.629,286 C 275.99,278.655 278.641,272.461 285.223,268.859 C 288.627,266.997 293.871,264.589 298.69,264.023 C 303.319,263.48 314.579,263.877 321.352,266.968 C 326.553,269.342 330.096,273.038 334.663,275.739 C 339.229,278.441 342.477,280.252 346.825,283.282 C 353.499,287.933 357.411,293.054 362.038,296.124 C 364.263,297.599 367.393,297.38 370.347,298.282 C 368.05,298.964 365.048,299.716 362.57,298.924 C 359.48,297.936 355.16,295.111 352.763,293.086 C 348.527,289.508 346.331,287.762 341.708,285.063 C 338.948,283.455 334.403,281.56 331.37,279.582 C 328.335,277.604 323.067,273.264 320.151,271.795 C 316.444,269.929 309.77,268.891 305.643,269.012 C 299.957,269.178 291.727,270.116 287.327,274.108 C 282.956,278.076 281.296,281.567 282.282,286.72 C 283.928,284.824 285.024,282.442 286.673,281.032 C 290.089,278.114 294.009,277.973 298.261,278.526 C 303.038,279.148 305.443,281.907 307.021,286.442 C 305.959,285.662 304.007,283.949 302.466,283.418 C 298.849,282.17 296.114,282.554 292.726,284.371 C 288.726,286.517 289.814,289.693 289.238,293.225 C 288.974,294.854 288.359,296.166 287.92,297.637 C 286.416,297.239 285.025,296.613 283.887,295.485 C 283.934,297.135 283.694,298.578 284.032,300.434 C 284.368,302.289 285.272,304.493 285.891,306.522 C 283.106,303.736 280.256,301.142 278.457,297.545 C 276.656,293.946 275.436,289.952 275.629,286 z M 280.449,232.54 C 282.502,229.493 283.103,224.819 284.369,221.019 C 283.863,225.832 284.836,231.125 282.486,234.611 C 280.136,238.097 276.009,237.486 272.59,238.5 C 275.25,236.472 278.395,235.587 280.449,232.54 z M 231.298,303.908 C 233.934,301.774 241.048,303.48 246.369,303.861 C 242.545,304.84 238.721,305.82 234.897,306.799 C 234.541,308.1 234.702,309.591 233.829,310.7 C 232.955,311.81 231.295,312.221 230.029,312.98 C 230.154,309.562 228.662,306.041 231.298,303.908 z M 268.789,155.688 C 271.965,157.398 275.996,159.659 278.801,159.729 C 281.606,159.799 282.34,157.895 283.99,156.796 C 286.586,165.261 289.566,174.562 293.986,182.243 C 295.838,185.461 297.019,183.965 298.427,187.199 C 299.833,190.432 300.458,197.011 301.792,201.142 C 303.128,205.273 304.87,208.313 306.409,211.898 C 302.501,206.361 297.452,199.301 295.274,194.693 C 293.098,190.086 294.491,189.685 292.729,185.297 C 290.967,180.909 287.405,174.069 284.743,168.455 C 282.837,168.708 280.477,169.055 279.028,168.608 C 277.579,168.161 277.868,166.62 276.559,165.624 C 275.248,164.628 273.045,165.014 271.209,163.424 C 269.373,161.835 268.955,158.574 268.789,155.688 z M 251.688,197.457 C 254.677,197.195 258.389,197.996 261.188,197.837 C 263.987,197.678 265.985,196.952 268.384,196.509 C 267.939,192.293 268.361,184.547 264.469,181.732 C 261.955,179.914 251.63,181.283 248.872,181.878 C 242.666,183.216 235.439,186.92 229.437,189.236 C 235.189,185.218 240.158,181.494 247.057,179.42 C 251.204,178.173 260.882,176.552 265.162,177.708 C 267.116,178.235 267.511,179.044 268.696,180.7 C 272.77,186.388 272.758,191.304 273.815,197.93 C 274.854,199.549 275.961,200.629 276.803,202.299 C 277.643,203.969 278.119,206.597 278.354,208.745 C 277.288,207.199 277.94,205.26 274.987,204.109 C 272.032,202.958 267.508,204.033 263.527,204.449 C 266.429,206.543 267.871,208.56 267.982,212.987 C 268.112,218.185 263.711,221.926 259.116,222.282 C 252.737,222.777 249.448,221.376 246.868,215.924 C 245.738,213.536 246.557,210.663 246.463,208.335 C 238.798,208.868 238.923,208.618 233.321,213.289 C 236.366,217.75 238.284,220.315 243.316,222.984 C 246.138,224.482 249.333,225.938 252.83,226.533 C 256.328,227.128 262.065,227.703 265.739,227.139 C 269.414,226.575 271.496,225.526 274.22,223.007 C 276.945,220.487 277.195,216.879 278.259,214.027 C 278.017,216.772 277.702,220.268 276.683,222.259 C 273.583,228.312 268.222,230.106 261.821,230.126 C 255.677,230.146 248.077,228.729 242.361,226.359 C 237.791,224.465 230.215,219.101 228.417,214.441 C 227.188,211.257 228.161,207.35 228.032,203.804 C 234.36,199.596 235.926,200.631 243.413,199.399 C 246.545,198.883 248.699,197.72 251.688,197.457 z M 214.827,168.956 C 215.005,166.435 215.284,166.489 215.513,165.255 C 209.748,163.713 207.436,167.453 204.056,174.399 C 202.791,176.998 204.043,178.545 202.686,180.256 C 201.331,181.967 199.147,181.727 196.946,183.37 C 194.745,185.012 192.564,188.157 190.506,189.858 C 186.283,193.349 180.575,195.48 175.677,197.829 C 179.022,195.361 185.513,191.618 187.613,188.032 C 188.727,186.131 188.562,182.546 190.296,180.837 C 192.029,179.127 192.636,177.944 194.874,177.508 C 197.112,177.072 196.212,174.478 196.934,172.416 C 197.656,170.354 199.094,168.89 200.624,166.83 C 202.154,164.77 204.084,161.677 207.105,160.554 C 210.126,159.43 214.837,160.645 217.124,159.998 C 219.41,159.351 218.097,157.689 219.758,156.691 C 221.421,155.693 224.654,156.133 226.875,155.066 C 230.812,153.173 232.695,150.013 235.063,146.63 C 235.407,153.912 235.323,159.155 232.706,166.006 C 229.759,173.717 226.772,178.259 218.408,183.001 C 215.526,184.634 212.658,185.201 210.269,186.058 C 211.662,184.158 213.656,183.333 214.449,180.358 C 215.24,177.381 214.649,171.478 214.827,168.956 z M 349.865,204.463 C 345.888,204.722 344.945,204.199 341.763,206.443 C 343.488,209.127 345.212,211.811 346.935,214.495 C 346.783,209.197 347.299,208.135 349.865,204.463 z M 339.445,200.613 C 344.953,198.267 349.752,196.369 355.744,195.994 C 358.146,195.843 361.875,196.215 364.301,196.325 C 366.367,193.283 369,190.884 369.965,187.412 C 370.604,185.109 370.289,174.42 369.158,171.645 C 365.863,163.569 362.66,163.228 358.125,158.602 C 354.834,155.247 354.703,150.138 353.719,144.413 C 353.358,142.31 352.326,139.649 351.842,137.479 C 345.914,136.48 339.539,136.151 332.719,136.492 C 336.026,133.32 339.223,130.422 340.172,125.66 C 341.119,120.898 340.348,115.043 337.641,110.773 C 334.934,106.503 330.61,102.783 326.641,99.304 C 322.67,95.825 316.979,92.953 313.217,90.107 C 318.11,88.355 323.106,85.781 327.899,84.852 C 340.385,82.43 351.143,86.134 363.186,93.415 C 370.188,97.65 375.979,101.673 383.299,109.336 C 390.617,116.998 399.694,131.053 406.779,139.388 C 413.864,147.723 419.584,154.315 425.765,159.286 C 431.947,164.258 437.542,165.674 443.429,168.867 L 452.605,178.611 L 460.031,169.422 L 471.98,170.773 L 474.449,157.361 L 485.416,154.356 L 483.627,136.276 L 491.512,130.68 L 485.586,119.431 L 491.607,107.139 L 483.757,93.088 L 486.784,79.559 L 477.696,71.814 L 476.51,57.437 L 463.832,52.601 L 458.746,40.093 L 444.492,39.933 L 437.5,30.648 L 427.904,31.32 L 417.207,30.155 L 411.158,25.689 L 402.379,31.517 L 391.756,25.978 L 370.639,33.995 L 384.405,22.023 L 398.667,19.745 L 409.593,16.96 L 424.349,21.806 L 437.337,18.516 L 449.86,25.919 L 463.112,25.186 L 469.622,36.867 L 482.817,38.39 L 489.956,51.377 L 498.255,55.908 L 500.458,72.545 L 507.849,79.555 L 504.599,94.112 L 513.306,105.136 L 505.142,116.948 L 513.872,124.331 L 502.712,134.222 L 514.015,145.993 L 500.365,150.395 L 509.256,163.02 L 498.106,164.944 L 505.418,178.826 L 492.852,178.659 L 499.182,189.057 L 485.399,187.398 L 488.696,202.357 L 478.28,193.194 L 474.712,211.324 L 467.524,198.306 L 463.631,214.543 L 454.758,202.57 L 455,219.596 L 445.193,204.287 C 447.261,212.973 446.847,222.484 452.552,230.673 C 470.228,228.281 481.781,223.827 495.323,210.796 C 507.657,198.928 522.399,174.183 526.391,158.488 C 530.946,140.578 531.086,107.638 526.6,89.404 C 522.282,71.848 516.67,63.462 506.643,49.136 C 497.059,38.957 487.633,28.204 475.469,20.945 C 457.613,10.29 434.717,7.417 414.367,7.694 C 403.099,7.848 395.551,10.012 388.814,12.462 C 377.033,16.746 367.611,26.091 355.634,30.709 C 351.728,32.214 348.597,32.261 345.521,30.618 C 348.533,36.644 351.81,39.347 359.322,41.54 C 364.756,43.126 377.722,42.123 386.648,41.299 C 396.23,40.414 401.228,37.565 414.269,37.744 C 427.005,37.919 437.097,42.757 442.615,45.912 C 454,52.422 462.164,59.644 469.258,71.084 C 473.154,77.366 475.883,84.454 477.805,91.687 C 479.727,98.92 480.569,107.021 480.692,114.102 C 480.815,121.183 480.274,127.504 478.542,133.876 C 474.491,148.794 465.554,163.974 447.196,161.629 C 435.962,160.193 419.026,139.107 413.354,131.371 C 401.909,115.758 390.133,98.481 375.752,85.479 C 366.984,77.554 354.979,72.1 343.19,71.021 C 321.073,68.997 314.514,73.198 297.866,86.92 C 301.253,88 304.559,88.596 308.03,90.16 C 315.733,93.631 322.778,98.117 328.923,103.871 C 335.362,109.902 338.251,113.719 338.48,122.355 C 338.632,128.09 333.914,132.688 329.589,136.824 C 326.943,139.357 323.441,141.676 321.298,143.642 C 318.458,146.251 314.941,149.105 318.509,153.261 C 319.851,154.823 322.181,156.001 324.146,157.46 C 327.265,159.775 325.837,168.379 321.728,170.661 C 316.47,173.578 310.187,173.252 305.851,169.347 C 311.324,168.528 314.8,167.802 314.658,163.325 C 314.576,160.73 311.277,158.574 308.039,157.098 C 300.23,153.538 294.332,154.063 286.56,148.471 C 278.71,142.82 278.537,139.726 276.415,130.854 C 272.63,131.25 269.145,131.337 264.084,133.013 C 259.023,134.688 253.43,138.676 248.835,139.663 C 237.263,142.153 234.957,141.415 228.624,139.776 C 217.474,136.89 202.956,141.831 188.534,146.444 C 186.136,147.211 176.437,146.47 169.908,148.761 C 159.824,152.299 145.675,160.867 137.503,167.749 C 125.121,178.178 108.849,209.389 99.655,245.213 C 98.689,256.103 101.786,263.44 94.926,268.759 C 88.066,274.078 88.256,287.705 85.93,291.527 C 83.604,295.348 80.911,293.659 75.904,299.026 C 70.897,304.393 68.348,303.496 68.474,313.644 C 72.789,310.807 79.08,307.509 84.604,307.31 C 89.496,307.133 89.548,313.574 102.104,301.161 C 108.819,294.52 121.72,294.317 130.671,291.388 C 139.623,288.459 155.754,282.423 171.91,264.361 C 188.066,246.299 195.797,227.284 198.93,199.794 C 199.429,204.668 200.295,210.165 198.208,223.61 C 196.121,237.055 191.623,252.156 201.099,270.244 L 207.003,281.513 C 203.488,276.716 196.622,268.891 194.555,263.315 L 189.787,250.452 C 179.12,267.2 176.668,270.196 161.85,282.195 C 161.26,289.639 161.115,297.403 163.548,304.526 C 165.981,311.648 162.103,319.858 163.954,324.549 C 165.805,329.24 170.086,326.57 171.484,331.319 C 172.882,336.068 170.754,345.457 172.922,350.086 C 175.09,354.715 180.409,351.906 182.987,353.401 C 185.565,354.897 186.408,356.947 187.787,358.914 C 189.165,360.88 187.248,365.528 190.052,367.037 C 192.855,368.547 197.228,367.268 200.145,368.717 C 203.062,370.166 203.505,373.649 202.806,376.77 C 202.106,379.891 198.989,381.323 197.62,384.496 C 196.252,387.67 196.405,389.879 198.049,392.793 C 199.693,395.708 203.333,397.313 206.961,398.784 C 210.589,400.255 215.687,399.429 219.431,401.463 C 223.175,403.497 226.54,407.55 228.517,410.496 C 230.494,413.441 231.043,415.519 230.942,418.616 C 230.84,421.712 229.584,425.279 227.931,428.27 C 226.278,431.261 222.631,434.901 228.325,440.613 C 234.019,446.324 233.809,443.862 237.071,447.567 C 236.716,441.158 234.068,435.937 236.004,431.112 C 237.941,426.287 243.756,425.448 246.821,423.278 C 249.886,421.107 251.651,418.125 254.067,415.549 C 254.032,418.864 254.387,422.428 254.01,424.924 C 253.242,429.999 251.744,434.504 259.307,435.318 C 262.714,435.684 265.949,433.475 269.534,432.149 C 267.656,435.512 264.39,438.216 263.899,442.241 C 263.408,446.264 263.998,450.684 266.784,454.677 C 269.571,458.668 274.383,461.632 277.909,463.978 C 281.434,466.325 283.323,466.513 286.032,467.782 C 286.165,471.738 285.386,475.925 285.837,479.651 C 286.288,483.377 287.462,486.675 289.616,489.755 C 291.772,492.836 295.229,494.603 298.485,496.881 C 296.7,492.724 293.079,488.78 293.128,484.41 C 293.177,480.041 294.487,476.944 298.749,473.067 C 303.011,469.189 312.989,465.826 317.694,462.056 C 322.399,458.285 323.917,455.975 325.606,452.314 C 327.295,448.653 326.825,442.755 327.137,439.464 C 328.686,444.074 328.907,445.507 329.41,450.33 C 329.916,455.154 326.599,461.92 325.195,465.491 C 331.015,462.68 334.709,458.187 336.574,453.796 C 337.822,454.536 337.193,456.565 337.652,460.475 C 339.726,458.411 342.084,456.823 344.172,454.875 C 346.262,452.929 348.551,451.217 349.588,448.5 C 350.623,445.783 350.199,442.894 349.428,439.737 C 348.657,436.58 345.129,432.919 343.229,429.466 C 341.331,426.014 343.565,422.625 343.436,418.465 C 339.635,417.812 336.407,415.876 332.038,416.505 C 327.667,417.133 322.661,422.038 318.194,422.095 C 313.727,422.152 311.219,417.967 307.557,416.817 C 303.895,415.667 300.19,415.793 296.508,415.281 C 301.172,410.813 319.274,408.685 331.656,406.666 C 342.551,404.889 353.363,403.862 364.402,403.707 C 369.332,403.637 375.668,405.265 379.091,404.281 C 382.517,403.299 381.786,400.966 382.802,398.423 C 385.644,391.315 384.243,384.985 382.697,377.827 C 372.787,376.665 362.461,375.243 352.476,376.01 C 342.714,376.76 331.154,381.401 321.085,381.715 C 312.331,381.987 299.368,380.038 291.851,375.456 C 282.665,369.857 275.558,357.832 273.035,353.971 C 268.926,347.682 263.743,335.344 260.589,329.703 C 257.437,324.062 256.742,322.484 254.119,320.129 C 251.496,317.775 247.903,317.593 244.796,316.324 C 248.378,316.69 252.289,315.556 255.543,317.422 C 260.432,320.227 265.904,331.853 268.946,336.912 C 272.169,326.108 271.417,321.86 280.743,315.768 C 273.227,324.192 273.04,330.573 271.208,340.491 C 277.458,350.749 286.147,367.089 297.517,371.623 C 301.624,373.262 308.677,374.29 313.117,374.839 C 326.935,376.55 340.263,372.171 353.834,368.82 C 363.754,366.37 373.82,367.357 385.885,368.066 C 389.981,368.306 399.639,365.842 401.639,361.699 C 402.719,359.464 402.639,356.778 401.088,354.396 C 399.535,352.014 395.399,350.862 393.182,348.718 C 390.965,346.574 389.69,344.029 387.944,341.684 C 378.729,343.452 371.149,344.131 364.309,344.317 C 369.215,342.296 373.922,341.143 379.028,339.146 C 384.134,337.149 389.932,333.871 394.053,331.151 C 398.174,328.43 400.805,326.852 403.787,323.686 C 406.767,320.518 410.59,317.255 412.787,313.383 C 414.986,309.511 415.326,305.18 415.449,300.388 C 415.572,295.597 415.365,288.874 413.517,285.014 C 411.671,281.155 408.111,279.984 405.251,279.071 C 402.39,278.158 400.431,280.467 397.456,280.779 C 394.479,281.091 391.698,282.967 387.394,280.943 C 383.09,278.919 377.988,274.799 373.636,268.684 C 369.286,262.568 366.175,252.572 361.74,244.882 C 354.095,231.626 344.568,219.243 335.457,206.96 C 334.707,203.931 333.58,199.745 333.205,195.636 C 332.551,188.476 332.428,181.038 334.65,174.058 C 336.353,168.711 338.83,163.063 344.429,160.87 C 346.669,159.992 349.503,159.644 351.505,160.386 C 353.509,161.127 355.474,163.388 354.687,166 C 353.822,168.872 351.832,168.95 350.48,170.4 C 348.185,172.86 347.267,174.665 346.4,177.732 C 348.88,177.692 352.232,177.503 354.269,178.039 C 356.927,178.739 359.402,180.501 360.751,184.267 C 357.579,181.454 356.003,180.163 352.044,180.063 C 350.23,180.018 348.026,180.667 346.019,180.969 C 345.269,183.409 344.828,186.401 343.769,188.289 C 342.71,190.177 340.648,189.724 339.874,191.93 C 339.1,194.132 339.055,197.718 339.445,200.613 z M 367.16,197.306 C 368.375,197.785 368.838,197.89 370.377,199.061 C 371.916,200.232 374.039,201.401 375.258,204.199 C 376.479,206.998 376.422,211.326 376.162,213.089 C 375.092,212.775 373.633,212.987 372.523,212.038 C 371.416,211.089 370.755,208.94 369.335,208.02 C 367.913,207.101 366.728,207.302 365.157,207.103 C 365.964,209.399 366.356,211.696 365.981,213.778 C 365.167,218.323 362.495,220.625 358.169,221.169 C 356.28,221.406 353.28,220.784 351.636,220.485 C 352.398,222.187 353.689,223.678 354.452,225.38 C 358.11,224.851 360.821,224.926 362.788,224.006 C 364.755,223.086 366.864,221.025 369.388,220.152 C 371.913,219.279 374.165,219.293 376.927,218.862 C 374.751,220.737 373.323,222.613 371.15,224.488 C 372.744,229.121 374.338,233.753 375.931,238.385 C 379.31,240.499 382.48,241.613 386.738,244.223 C 390.998,246.834 396.105,251.504 401.652,254.051 C 407.199,256.598 410.502,257.984 416.298,259.077 C 422.093,260.17 426.704,264.864 432.407,265.627 C 438.11,266.39 448.762,266.544 453.157,266.115 C 458.147,265.628 464.63,263.053 465.212,257.582 C 461.028,258.614 454.638,257.688 451.411,249.815 C 449.979,246.319 450.681,239.89 448.489,235.756 C 446.298,231.621 443.243,230.294 439.593,225.2 C 435.943,220.106 429.972,212.071 426.62,205.246 C 423.27,198.422 422.481,190.692 419.647,184.577 C 416.813,178.463 412.538,173.524 409.225,168.811 C 401.991,158.511 396.157,151.472 384.239,146.276 C 378.507,143.777 371.981,143.111 365.852,141.528 C 363.358,142.645 359.938,143.879 359.331,146.796 C 358.724,149.713 359.89,154.021 362.007,156.211 C 365.55,159.872 370.8,163.829 372.864,169.648 C 374.19,173.382 374.575,185.9 373.426,189.297 C 372.234,192.824 369.463,194.957 367.16,197.306 z M 368.314,226.935 C 367.207,227.89 366.363,228.871 364.582,229.664 C 362.803,230.457 360.373,230.662 358.012,231.252 C 361.323,236.406 364.801,241.614 367.973,247.033 C 371.147,252.451 373.897,258.384 376.926,264.058 C 376.783,260.806 376.975,257.339 376.502,254.3 C 376.029,251.262 374.652,248.603 373.287,244.042 C 371.924,239.481 370.246,233.276 368.314,226.935 z M 279.229,113.611 C 278.762,118.681 279.62,126.607 280.67,131.571 C 281.928,137.513 283.139,140.594 287.961,144.174 C 296.791,150.729 302.428,149.624 309.221,153.425 C 312.453,155.234 316.549,158.266 317.744,161.471 C 318.939,164.676 316.955,168.156 314.504,169.524 C 318.791,170.162 323.598,165.329 321.592,160.367 C 320.604,157.925 315.901,156.837 314.459,154.373 C 313.02,151.91 313.023,149.374 313.701,146.872 C 314.926,142.362 323.849,138.264 327.002,134.699 C 331.854,129.213 333.717,124.624 330.969,117.559 C 327.11,107.634 312.201,99.67 303.278,95.775 C 299.192,93.992 296.901,93.865 293.714,92.91 C 300.239,96.734 307.118,99.78 310.419,108.328 C 313.175,115.467 310.788,118.157 310.88,124.373 C 310.923,127.255 314.718,128.696 316.403,130.517 C 317.87,132.1 317.751,133.275 316.579,135.46 C 316.45,133.489 315.608,132.018 314.095,130.947 C 311.597,129.176 308.906,129.557 307.575,125.926 C 305.555,120.406 309.561,115.178 305.057,108.98 C 301.688,104.343 297.207,99.153 291.162,99.017 C 288.301,98.952 286.15,99.384 283.094,100.288 L 279.02,95.385 L 278.926,95.321 C 270.639,87.758 264.969,81.525 253.344,76.327 C 241.719,71.13 235.99,70.343 222.661,70.639 C 209.332,70.934 196.104,72.049 180.666,85.362 C 165.229,98.675 125.442,149.654 115.793,156.106 C 106.145,162.558 104.008,164.744 91.952,164.747 C 79.896,164.75 61.08,147.697 60.343,126.385 C 59.605,105.072 59.309,97.497 74.124,71.822 C 88.94,46.146 115.78,38.262 135.694,35.6 C 155.609,32.938 167.576,39.952 182.307,39.985 C 197.037,40.019 211.595,37.476 215.888,25.761 C 213.787,27.012 210.972,28.422 203.056,28.007 C 195.14,27.592 184.164,18.427 171.817,12.286 C 159.47,6.146 145.73,5.427 128.107,5.094 C 110.484,4.761 88.494,6.108 66.708,17.869 C 44.922,29.63 30.051,42.109 17.415,65.127 C 4.779,88.146 2.891,106.94 4.928,134.811 C 6.965,162.682 15.561,183.41 32.112,203.809 C 48.663,224.208 65.204,234.189 95.03,237.9 L 101.309,210.204 L 90.1,226.29 L 90.377,208.399 L 80.238,220.98 L 75.791,203.918 L 67.577,217.597 L 63.497,198.547 L 51.594,208.174 L 55.362,192.455 L 39.612,194.198 L 46.847,183.272 L 32.486,183.447 L 40.842,168.86 L 28.1,166.837 L 38.26,153.57 L 22.66,148.945 L 35.576,136.577 L 22.823,126.184 L 32.798,118.426 L 23.47,106.014 L 33.42,94.431 L 29.706,79.135 L 38.155,71.77 L 40.67,54.289 L 50.152,49.527 L 58.31,35.881 L 73.389,34.28 L 80.829,22.006 L 95.974,22.777 L 110.286,14.998 L 125.129,18.455 L 141.989,13.363 L 154.476,16.289 L 170.772,18.684 L 186.505,31.264 L 162.372,22.84 L 150.232,28.661 L 140.197,22.536 L 133.288,27.229 L 121.063,28.453 L 110.1,27.745 L 102.108,37.501 L 85.817,37.669 L 80.006,50.812 L 65.52,55.894 L 64.165,71.001 L 53.777,79.139 L 57.238,93.355 L 48.267,108.12 L 55.149,121.035 L 48.376,132.855 L 57.387,138.735 L 55.343,157.733 L 67.875,160.891 L 70.698,174.984 L 84.354,173.565 L 92.838,183.221 L 103.324,172.982 C 122.44,163.45 130.312,158.118 145.21,142.005 C 162.169,123.662 171.889,106.703 194.479,94.144 C 210.681,85.136 223.896,81.894 242.096,85.039 C 259.184,87.991 264.906,98.241 277.491,109.039 C 278.825,106.624 279.096,105.984 281.294,104.206 C 280.604,107.342 279.508,110.595 279.229,113.611 z "
         style="fill-rule:evenodd"
         id="path4908" />
        </g>
      </g>
    </svg>
  '''

_ = window._ or require 'underscore'
$ = window.jQuery or require 'jquery'

Curve.Utils =
  getObjectFromNode: (domNode) ->
    $.data(domNode, 'curve.object')
  setObjectOnNode: (domNode, object) ->
    $.data(domNode, 'curve.object', object)
