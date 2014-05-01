zmq             = require 'zmq'
uuid            = require 'node-uuid'

_               = require 'lodash'

MessageTypes    = require('./message-enums').Types
TypesToFuncs    = require('./message-enums').TypesToFuncs
FuncsToTypes    = require('./message-enums').FuncsToTypes

DEFAULT_SEND_TIMEOUT = 5000

class IPCClient 
    
    constructor : (connectionString, options, @parser = JSON) ->
        
        if not _.isString connectionString
            return this

        @subscriptors = {}

        @timeouts = {}
        
        @sockets = {}

        @callbacks = {}
        
        @statelessCallbacks = {}

        @statelessMessageTypes = _.keys TypesToFuncs
        
        @sendTimeout = options?.sendTimeout || DEFAULT_SEND_TIMEOUT
            
        @uuidBase = uuid.v4().substring(0, 24).replace(/[-]+/g, '')
        @uuidCounter = 0
        
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

    
    # Метод регистрации коллбэка для реакции на сообщение с определенным типом 
    on : (messageType, func) -> 
        
        @statelessCallbacks[messageType.toString()] = func


    onInvokeReply : (parsedMessage) ->
    
        hashKey = @buildHashKey(parsedMessage.func, parsedMessage.id)

        clearTimeout @timeouts[hashKey]
        delete @timeouts[hashKey]

        func = @callbacks[hashKey]

        if not _.isFunction func
            return

        func(parsedMessage.error, parsedMessage.res)

        @callbacks[hashKey] = undefined
        
        
    onStatelessReply : (parsedMessage) ->
        
        handler = @statelessCallbacks[parsedMessage.type.toString()]
        
        if handler?
            handler parsedMessage.error, parsedMessage.res, parsedMessage.context 
            
        undefined
        
        
    message : (message) ->

        message = message.toString()
        message = @parser.parse message
        
        if message.type == MessageTypes.InvokeSyncReply
            @onInvokeReply message
        else if @statelessMessageTypes.indexOf(message.type.toString()) >= 0
            @onStatelessReply message
        else 
            console.log 'IPClient: Unhandled message: %j', message 
            
    #Метод используется для обмена stateless сообщениями, то есть мы не знаем, когда придет ответ,
    #поэтому не блокируем процесс на ожидании, и предполагаем, что ответ будет содержать все данные, 
    #необходимые для корректной его обработки, независимо от того, вылетал ли клиент или сервер в процессе roundtrip-а
    request : (func, args) ->
        
        if not _.isString func
            return isError: true, error : 'invalid function name'

        type   = FuncsToTypes[func]
        
        if not type?
            return isError: true, error : 'function not allowed for stateless messaging'
            
        obj =
            id          : uuid
            clientId    : @clientId
            func        : func
            arguments   : args
            type        : FuncsToTypes[func]

        str = @parser.stringify(obj)

        @socket.send str
        
            
    invoke : (func, args, callback) ->

        if not _.isString func
            return callback? error : 'invalid function name'

        uuid = @fastUUID()

        hashKey = @buildHashKey(func, uuid)

        @callbacks[hashKey] = callback

        obj =
            id          : uuid
            clientId    : @clientId
            func        : func
            arguments   : args
            type        : MessageTypes.InvokeSyncRequest

        str = @parser.stringify(obj)

        @socket.send str
        
        @timeouts[hashKey] = setTimeout =>

            #have to remove callback from registered callbacks hash to avoid second call 
            @callbacks[hashKey] = undefined 
            #and call callback with timeout error
            
            callback new Error "Timeout of #{@sendTimeout} msec exceeded"

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
