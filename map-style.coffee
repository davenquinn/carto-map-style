{readFileSync} = require 'fs'
{safeLoad} = require 'js-yaml'
path = require 'path'
{Renderer} = require 'carto'
callsite = require 'callsite'
{existsSync} = require 'fs'
_ = require 'underscore'

cartoRenderer = new Renderer

class MapStyle
  ### A proxy for a CartoCSS stylesheet ###
  @layerDirectory: do ->
    try
      text = readFileSync process.env.MAPNIK_LAYERS, 'utf8'
      safeLoad text
    catch
      return {}

  @stylesheetDir: process.env.MAPNIK_STYLES
  srs: null
  constructor: (opts={})->
    @Layer ?= []
    @Stylesheet ?= []
    @srs ?= opts.srs
    opts.layers ?= []
    opts.styles ?= []

    @Layer = opts.layers.map (id)=>
      if _.isString id
        lyr = @constructor.layerDirectory[id] or {}
        lyr.id = id
      else
        lyr = id
      console.log lyr
      lyr.name ?= lyr.id
      lyr.srs ?= @srs
      return lyr

    ### Add computed styles to stylesheet ###
    for style in opts.styles
      ### Try getting locally first ###
      if _.isString style
        style = @__getNamedStyle style
      @Stylesheet.push style

    delete opts.layers
    delete opts.styles

    for k,v in opts
      @[k] = v

  __getNamedStyle: (id)=>
    sourceFile = null

    if id.endsWith '.mss'
      console.log "Checking path #{id} for stylesheet"
      sourceFile = id if existsSync id

    try
      sourceFile ?= path.join @constructor.stylesheetDir, "#{id}.mss"
    catch
      throw "Couldn't find stylesheet directory, maybe it isn't defined?"

    {name} = path.parse sourceFile
    data = readFileSync(sourceFile,'utf8')
    return {id: name, data, sourceFile}

  toXml: =>
    cartoRenderer.render @

class CartoStyle
  constructor: (fn)->
    dirname = path.dirname(fn)
    obj = JSON.parse readFileSync(fn, 'utf8')
    @base = dirname
    for k,v of obj
      @[k] = v
    @Stylesheet.forEach (d,i)=>
      if _.isString d
        sourceFile = path.join dirname, d
        data = readFileSync(sourceFile,'utf8')
        @Stylesheet[i] = {id: d, data}

## Database Layer ##
class PostGISLayer
  defaultDatasource:
    dbname: "Naukluft"
    geometry_field: "geometry"
    host: "localhost"
    port: 5432
    table: null
    type: 'postgis'
    srid: null
  constructor: (@id, sqltext, opts={})->
    for k, def of @defaultDatasource
      opts[k] ?= def
    @Datasource = opts
    if sqltext.query?
      # We passed a pg-promise prepared statement
      # NOTE: newer versions of pgp don't have this defined.
      sqltext = sqltext.query
    # Convert to subquery format
    @Datasource.table = "(#{sqltext}) AS a"

module.exports = {MapStyle,PostGISLayer,CartoStyle}
