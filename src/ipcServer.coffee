zmq         = require 'zmq'
cron        = require 'cron'
_           = require 'lodash'

class IPCServer

    constructor : (@serverContext, @options, @parser = JSON, @hbSeconds = 2) ->

        @clients = {}
        
        @socket = zmq.socket 'rep'
        
        if @hbSeconds?
            
            @heartbeatCnt = 0
            
            @heartbeatSocket = zmq.socket 'pub'

            new cron.CronJob "*/#{@hbSeconds} * * * * *", (() => @.heartbeat()), null, true
        
        @socket.on "message", (reply) => 
            @.message(reply)

        @socket.on "error", (error) => 
            @.error(error)

    getClientContext : (clientId) ->

        if not @clients[clientId]
            ctx =
                counter : -1
                id : clientId

            @clients[clientId] = ctx 

        return @clients[clientId]

    register : (ctx, clientId, callback) ->

        clientContext = @getClientContext clientId
            
        callback? null, clientContext
        
    message : (message) ->
        
        message = JSON.parse message.toString()

        ctx = @getClientContext message.clientId

        func = @serverContext[message.func]

        if not _.isFunction func
            return @reply message.id, message.func, 'action not registered'

        func ctx, message.arguments, (error, result) =>

            @reply message.id, message.func, error, result

            
    error : (error) ->
        console.log error

        
    heartbeat : () ->
        
        if @heartbeatCnt + 1 > 0xffffffff
            @heartbeatCnt = 0

        hb = { type: 1, cnt : @heartbeatCnt++ }

        hb  = @parser.stringify(hb)

        result = @heartbeatSocket.send hb

        #console.log 'heartbeat', @heartbeatCnt, result
        

    reply : (id, funcName, error = null, result = undefined) ->
        
        reply = { type: 2, id: id, func: funcName, error : error, res : result }

        reply  = @parser.stringify(reply)

        @socket.send reply
        
           
    bind : (type='tcp', address='127.0.0.1', port='17077') ->

        if not _.isString address
            return false
            
        string = "#{type}://#{address}:#{port}"
            
        @socket.bindSync string
        
        hbPort = parseInt(port)+1

        hbString = "#{type}://#{address}:#{hbPort}"

        @heartbeatSocket.bindSync hbString
        
    bindPub : () ->
        
   
module.exports = IPCServer