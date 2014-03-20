zmq             = require 'zmq'
uuid            = require 'node-uuid'

_               = require 'lodash'

class IPCClient 
    
    constructor : (connectionString, @options, @parser = JSON, hb = true) ->
        
        if not _.isString connectionString
            return this

        @uuidBase = uuid.v4().substring(0, 24).replace(/[-]+/g, '')
        @uuidCounter = 0
        
        @callbacks = {}
        @clientId = uuid.v1()
        @clientId = @clientId.toString().replace(/[-]+/g, '')
        
        @socket = zmq.socket 'req'
        
        @socket.on "message", (reply) => 
            @message(reply)

        @socket.connect(connectionString)

        if hb
            @heartbeatCnt = -1
            
            @heartbeatSocket = zmq.socket 'sub'
            @heartbeatSocket.on "message", (hb) =>
                @heartbeat(hb)

            hbPort = connectionString.slice(connectionString.lastIndexOf(':')+1)
            
            hbPort = parseInt hbPort
            
            hbPort++
            
            hbConnectionString = connectionString.slice 0, -hbPort.toString().length
            
            hbConnectionString += hbPort.toString()
            
            @heartbeatSocket.connect(hbConnectionString);
            @heartbeatSocket.subscribe('')


    register : (callback)->
        @invoke 'register', @clientId, callback
        

    message : (message) ->

        message = message.toString()
        message = @parser.parse message

        if message.type == 2
            hashKey = @buildHashKey(message.func, message.id)

            func = @callbacks[hashKey]
            
            if not _.isFunction func
                return
            
            func(message.error, message.res)

    heartbeat : (message) ->
        message = message.toString()
        message = @parser.parse message

        if @heartbeatCnt == -1
            @heartbeatCnt = message.cnt
            return

        diff = message.cnt - @heartbeatCnt
            
        if message.cnt - @heartbeatCnt != 1
            console.log "missed #{diff} hb"

        @heartbeatCnt = message.cnt
        
    invoke : (func, args, callback) ->
        
        if not _.isString func
            return callback? { error : 'invalid function name' }
            
        uuid = @fastUUID()
        
        hashKey = @buildHashKey(func, uuid)
            
        @callbacks[hashKey] = callback
        
        obj =
            id : uuid
            clientId : @clientId
            func : func
            arguments : args
        
        str = @parser.stringify(obj)

        @socket.send str
        
    subscribe : (connString, channel, func) ->

    fastUUID : () ->
        counter = @uuidCounter++
        #Just in the case user sends over 281 trillion messages?
        if(@uuidCounter > 0xFFFFFFFFFFFF) 
            @uuidCounter = 0        
        return @uuidBase + ("000000000000" + counter.toString(16)).slice(-12)

    buildHashKey : (func, uuid) ->
        func + '_' + uuid
        
        
module.exports = IPCClient