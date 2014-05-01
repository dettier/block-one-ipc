zmq         = require 'zmq'
cron        = require 'cron'
_           = require 'lodash'

MessageTypes    = require('./message-enums').Types
TypesToFuncs    = require('./message-enums').TypesToFuncs
FuncsToTypes    = require('./message-enums').FuncsToTypes

defaultPort     = '17077'
defaultPubPort  = '17088'


class IPCServer

    constructor : (@serverContext, @options, @parser = JSON, @hbSeconds = 2) ->

        @clients = {}
        
        @socket = zmq.socket 'rep'

        @heartbeatCnt = 0

        @pubSockets = {}
        
        @existingAddresses = {}

        @statelessMessageTypes = _.keys TypesToFuncs
        
        if @hbSeconds?
            
            if @hbSeconds > 60
                @hbSeconds = 60
                
            new cron.CronJob "*/#{@hbSeconds} * * * * *", (() => @.heartbeat()), null, true
        
        @socket.on "message", (req) => 
            @message req

        @socket.on "error", (error) => 
            @error error

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
            return @reply message.id, message.func, message.type + 1, message.arguments, 'action not registered'

        func ctx, message.arguments, (error, result) =>

            @reply message.id, message.func, message.type + 1, message.arguments, error, result

            
    error : (error) ->
        console.log error

        
    heartbeat : () ->
        
        if @heartbeatCnt + 1 > 0xffffffff
            @heartbeatCnt = 0

        hb = { type: 1, cnt : @heartbeatCnt++ }

        result = @publish 'heartbeat', '', 'hb', hb

        #console.log 'heartbeat', @heartbeatCnt, result
    

    publish : (channel, subchannel, event, data) ->

        data = @parser.stringify data

        #message = (channel || '') + '|' + (subchannel || '') + '|' + (event || '') + '|' + data
        message = (channel || '') + ' ' + data

        sockets = @pubSockets[channel]
        
        _.forEach sockets, (socket) ->
            socket.send message


    reply : (id, funcName, type = MessageTypes.InvokeSyncReply, args, error = null, result = undefined) ->
        
        reply = { type: type, id: id, func: funcName, error : error, res : result }

        #we have to fully retransmit message arguments for correct handling of stateless messages  
        if @statelessMessageTypes.indexOf(type.toString()) >= 0
            reply.args = args    
        
        reply  = @parser.stringify reply

        @socket.send reply
        
    
    bind : (type='tcp', address='127.0.0.1', port=defaultPort) ->

        if not _.isString address
            return false

        if type == 'tcp'
            string = "#{type}://#{address}:#{port}"
        else
            string = "#{type}://#{address}"            
            
        @socket.bindSync string
        
    
    createPubChannel : (channel, type='tcp', address='127.0.0.1', port=defaultPubPort) ->
        
        if type == 'tcp'
            string = "#{type}://#{address}:#{port}"
        else 
            string = "#{type}://#{address}"

        #проверяем, создан ли сокет с заданным адресом
        addrs = @existingAddresses[channel] ?= []        
            
        if addrs[string]?
            return

        @existingAddresses[channel].push string
        
        sockets = @pubSockets[channel] ?= []
        
        socket = zmq.socket 'pub'

        #ставим публикатор на указанный адрес
        socket.bindSync string

        sockets.push socket

        @pubSockets[channel] = sockets

   
module.exports = IPCServer