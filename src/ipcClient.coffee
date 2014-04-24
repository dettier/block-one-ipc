zmq             = require 'zmq'
uuid            = require 'node-uuid'

_               = require 'lodash'

DEFAULT_SEND_TIMEOUT = 5000

class IPCClient 
    
    constructor : (connectionString, options, @parser = JSON) ->
        
        if not _.isString connectionString
            return this

        @subscriptors = {}

        @timeouts = {}
        
        @sockets = {}
        
        @sendTimeout = options?.sendTimeout || DEFAULT_SEND_TIMEOUT
            
        @uuidBase = uuid.v4().substring(0, 24).replace(/[-]+/g, '')
        @uuidCounter = 0
        
        @callbacks = {}
        @clientId = uuid.v1()
        @clientId = @clientId.toString().replace(/[-]+/g, '')

        @socket = zmq.socket 'req'

        @socket.on "message", (reply) => 
            @message(reply)

        @socket.on "error", (error) =>
            @error(error)            

        @socket.connect(connectionString)


    register : (callback)->
        @invoke 'register', @clientId, callback


    error : (error) ->
        
        console.log error
        

    message : (message) ->

        message = message.toString()
        message = @parser.parse message

        if message.type == 2
            hashKey = @buildHashKey(message.func, message.id)
            
            clearTimeout @timeouts[hashKey]
            delete @timeouts[hashKey]

            func = @callbacks[hashKey]
            
            if not _.isFunction func
                return
            
            func(message.error, message.res)
            
            @callbacks[hashKey] = undefined

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
        
        @timeouts[hashKey] = setTimeout =>

            #have to remove callback from registered callbacks hash to avoid second call 
            @callbacks[hashKey] = undefined 
            #and call callback with timeout error
            callback new Error('Timeout of', @sendTimeout, 'msec exceeded')

        , @sendTimeout
            
        

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
        
    
    subError : (channel, err, func) ->

        console.log channel, 'error:', err

        
    
    subscribe : (connString, channel, subchannel, event, func) ->
        
        if _.isFunction subchannel
            func = subchannel
            event = ''
            subchannel = ''
        else if _.isFunction event
            func = event
            event = ''
        
        socket = @sockets[channel] = zmq.socket 'sub'

        filter = channel || ''
        
        @subscriptors[filter] = func
        
        socket.on "message", (message) =>

            message = message.toString()
            
            parts = message.split " "
            
            channel = parts[0]
            data = parts[1]
            
            data = @parser.parse data
            
            data.channel = channel
            return func data

        socket.on "error", (err) =>
            
            @subError(channel, err, func)

        sock = socket.connect connString
        
        socket.subscribe filter

        
    fastUUID : () ->
        counter = @uuidCounter++
        #Just in the case user sends over 281 trillion messages?
        if(@uuidCounter > 0xFFFFFFFFFFFF) 
            @uuidCounter = 0        
        return @uuidBase + ("000000000000" + counter.toString(16)).slice(-12)

    buildHashKey : (func, uuid) ->
        func + '_' + uuid
        
        
module.exports = IPCClient