var IPCClient, uuid, zmq, _;

zmq = require('zmq');

uuid = require('node-uuid');

_ = require('lodash');

IPCClient = (function() {
  function IPCClient(connectionString, options, parser, hb) {
    var hbConnectionString, hbPort,
      _this = this;
    this.options = options;
    this.parser = parser != null ? parser : JSON;
    if (hb == null) {
      hb = true;
    }
    if (!_.isString(connectionString)) {
      return this;
    }
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
    if (hb) {
      this.heartbeatCnt = -1;
      this.heartbeatSocket = zmq.socket('sub');
      this.heartbeatSocket.on("message", function(hb) {
        return _this.heartbeat(hb);
      });
      hbPort = connectionString.slice(connectionString.lastIndexOf(':') + 1);
      hbPort = parseInt(hbPort);
      hbPort++;
      hbConnectionString = connectionString.slice(0, -hbPort.toString().length);
      hbConnectionString += hbPort.toString();
      this.heartbeatSocket.connect(hbConnectionString);
      this.heartbeatSocket.subscribe('');
    }
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

  IPCClient.prototype.subscribe = function(connString, channel, func) {};

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
