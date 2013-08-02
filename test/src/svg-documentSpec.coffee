describe 'Curve.SvgDocument', ->
  beforeEach ->
    loadFixtures 'canvas.html'
    @s = new Curve.SvgDocument($('#canvas')[0])

  it 'has a tool layer', ->
    expect($('#canvas svg>.tool-layer')).toExist()

  describe 'importing svg', ->
    beforeEach ->

    it 'will load an svg document', ->
      @s.import(DOCUMENT)

      expect($('#canvas svg>svg')).toExist()
      expect($('#canvas svg>svg #arrow')).toExist()

    it 'places tool things in the tool layer', ->
      @s.import(DOCUMENT)

      @s.objects[0]
      @s.selectionModel.setSelected(@s.objects[0])
      @s.selectionModel.setSelectedNode(@s.objects[0].subpaths[0].nodes[0])

      expect($('#canvas .tool-layer .node-editor-node')).toExist()
      expect($('#canvas .tool-layer .object-selection')).toExist()

DOCUMENT = '''
  <svg height="1024" width="1024" xmlns="http://www.w3.org/2000/svg">
    <path id="arrow" d="M512,384L320,576h128v320h128V576h128L512,384z"/>
  </svg>
  '''

DOCUMENT_WITH_XML_HEADER = '''
  <?xml version="1.0" encoding="UTF-8" standalone="no"?>
  <svg height="1024" width="1024" xmlns="http://www.w3.org/2000/svg">
    <path id="arrow" d="M512,384L320,576h128v320h128V576h128L512,384z"/>
  </svg>
  '''

DOCUMENT_NO_ARROW = '''
  <svg height="1024" width="1024" xmlns="http://www.w3.org/2000/svg">
    <path id="not-an-arrow" d="M512,384L320,576h128v320h128V576h128L512,384z"/>
  </svg>
  '''
