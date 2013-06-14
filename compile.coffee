#!node_modules/.bin/coffee

Q = require "q"
fs = require "fs"
path = require "path"
jade = require "jade"
parseXml = Q.denodeify (require "xml2js").parseString
argv = process.argv

readFile = Q.denodeify fs.readFile
writeFile = Q.denodeify fs.writeFile


# Some variables
VIEW = "model.jade"
DEBUG = true
PRETTY = false

# The actual work
buildKml = (nodes, links) -> Q
  .fcall ->
    # parse input files
    console.error "Parsing XML..."
    [parseXml(nodes), parseXml(links)]

  .spread (nodes, links) ->
    # validate input
    console.error "Perparing to process..."
    if nodes.cnml.class[0].$.network_description != "nodes"
      throw new Error "The CNML should be at «node» level."
    if nodes.cnml.network[0].zone.length != 1
      throw new Error "There should be exactly ONE zone."
    if nodes.cnml.network[0].node?
      throw new Error "Everything should be inside the root zone."
    if nodes.cnml.network[0].zone[0].$.title != "guifi.net World"
      throw new Error "The CNML needs to be from the root zone."

    # compile the view
    compileView(VIEW)

    .then (view) ->
      # produce output
      console.error "Processing..."
      view cnml: nodes.cnml
         , ldoc: links
         , net: nodes.cnml.network[0]
         , world: nodes.cnml.network[0].zone[0]

# Compile the view
compileView = (file) -> Q
  .fcall ->
    file = path.join __dirname, file
    readFile file, "utf8"
  .then (view) ->
    jade.compile view,
      filename: file
      debug: DEBUG
      compileDebug: DEBUG
      pretty: PRETTY
      locals: api: earthApi


# Parse arguments
if argv.length != 4
  console.error "Usage: ./#{path.basename module.filename} [nodes cnml] [links gml]"
  process.exit 1

[nodes, links] = argv.slice 2

Q

  .fcall ->
    # read the files
    console.error "Reading files..."
    [readFile(nodes,"utf8")
     readFile(links,"utf8")]

  .spread (nodes, links) ->
    # GO
    buildKml nodes, links

  .then (output) ->
    # print to stdout
    console.error "Done processing."
    process.stdout.write output

.done()


# The API which is made available to the template
earthApi =
   # convert 'regular' color to Google Earth
   col: (col, a) ->
     if col[0] is '#'
        col = col.substr 1
     unless a? then a=1
       a = (a*255).toString 16
     if a.length is 1
       a = '0'+a
     r = col.substr 0,2
     g = col.substr 2,4
     b = col.substr 4,6
     "#"+a+b+g+r


