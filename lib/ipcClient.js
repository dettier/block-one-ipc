var IPCClient, uuid, zmq, _;

zmq = require('zmq');

uuid = require('node-uuid');

_ = require('lodash');

IPCClient = (function() {
  function IPCClient(connectionString, options, parser) {
    var _this = this;
    this.options = options;
    this.parser = parser != null ? parser : JSON;
    if (!_.isString(connectionString)) {
      return this;
    }
    this.sockets = {};
    this.uuidBase = uuid.v4().substring(0, 24).replace(/[-]+/g, '');
    this.uuidCounter = 0;
    this.callbacks = {};
    this.clientId = uuid.v1();
    this.clientId = this.clientId.toString().replace(/[-]+/g, '');
    this.socket = zmq.socket('req');
    this.socket.on("message", function(reply) {
      return _this.message(reply);
    });
    this.socket.connect(connectionString);
  }

  IPCClient.prototype.register = function(callback) {
    return this.invoke('register', this.clientId, callback);
  };

  IPCClient.prototype.message = function(message) {
    var func, hashKey;
    message = message.toString();
    message = this.parser.parse(message);
    if (message.type === 2) {
      hashKey = this.buildHashKey(message.func, message.id);
      func = this.callbacks[hashKey];
      if (!_.isFunction(func)) {
        return;
      }
      return func(message.error, message.res);
    }
  };

  IPCClient.prototype.invoke = function(func, args, callback) {
    var hashKey, obj, str;
    if (!_.isString(func)) {
      return typeof callback === "function" ? callback({
        error: 'invalid function name'
      }) : void 0;
    }
    uuid = this.fastUUID();
    hashKey = this.buildHashKey(func, uuid);
    this.callbacks[hashKey] = callback;
    obj = {
      id: uuid,
      clientId: this.clientId,
      func: func,
      "arguments": args
    };
    str = this.parser.stringify(obj);
    return this.socket.send(str);
  };

  IPCClient.prototype.heartbeat = function(message) {
    var diff;
    message = message.toString();
    message = this.parser.parse(message);
    if (this.heartbeatCnt === -1) {
      this.heartbeatCnt = message.cnt;
      return;
    }
    diff = message.cnt - this.heartbeatCnt;
    if (message.cnt - this.heartbeatCnt !== 1) {
      console.log("missed " + diff + " hb");
    }
    return this.heartbeatCnt = message.cnt;
  };

  IPCClient.prototype.subError = function(channel, err, func) {
    return console.log(channel, 'error:', err);
  };

  IPCClient.prototype.subscribe = function(connString, channel, func) {
    var socket,
      _this = this;
    socket = this.sockets[channel] = zmq.socket('sub');
    socket.on("message", function(msg) {
      return func(msg);
    });
    socket.on("error", function(err) {
      return _this.subError(channel, err, func);
    });
    socket.connect(connString);
    return socket.subscribe(channel);
  };

  IPCClient.prototype.fastUUID = function() {
    var counter;
    counter = this.uuidCounter++;
    if (this.uuidCounter > 0xFFFFFFFFFFFF) {
      this.uuidCounter = 0;
    }
    return this.uuidBase + ("000000000000" + counter.toString(16)).slice(-12);
  };

  IPCClient.prototype.buildHashKey = function(func, uuid) {
    return func + '_' + uuid;
  };

  return IPCClient;

})();

module.exports = IPCClient;
