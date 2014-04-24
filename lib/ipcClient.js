var DEFAULT_SEND_TIMEOUT, IPCClient, uuid, zmq, _;

zmq = require('zmq');

uuid = require('node-uuid');

_ = require('lodash');

DEFAULT_SEND_TIMEOUT = 5000;

IPCClient = (function() {
  function IPCClient(connectionString, options, parser) {
    var _this = this;
    this.parser = parser != null ? parser : JSON;
    if (!_.isString(connectionString)) {
      return this;
    }
    this.subscriptors = {};
    this.timeouts = {};
    this.sockets = {};
    this.sendTimeout = (options != null ? options.sendTimeout : void 0) || DEFAULT_SEND_TIMEOUT;
    this.uuidBase = uuid.v4().substring(0, 24).replace(/[-]+/g, '');
    this.uuidCounter = 0;
    this.callbacks = {};
    this.clientId = uuid.v1();
    this.clientId = this.clientId.toString().replace(/[-]+/g, '');
    this.socket = zmq.socket('req');
    this.socket.on("message", function(reply) {
      return _this.message(reply);
    });
    this.socket.on("error", function(error) {
      return _this.error(error);
    });
    this.socket.connect(connectionString);
  }

  IPCClient.prototype.register = function(callback) {
    return this.invoke('register', this.clientId, callback);
  };

  IPCClient.prototype.error = function(error) {
    return console.log(error);
  };

  IPCClient.prototype.message = function(message) {
    var func, hashKey;
    message = message.toString();
    message = this.parser.parse(message);
    if (message.type === 2) {
      hashKey = this.buildHashKey(message.func, message.id);
      clearTimeout(this.timeouts[hashKey]);
      delete this.timeouts[hashKey];
      func = this.callbacks[hashKey];
      if (!_.isFunction(func)) {
        return;
      }
      func(message.error, message.res);
      return this.callbacks[hashKey] = void 0;
    }
  };

  IPCClient.prototype.invoke = function(func, args, callback) {
    var hashKey, obj, str,
      _this = this;
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
    this.socket.send(str);
    return this.timeouts[hashKey] = setTimeout(function() {
      _this.callbacks[hashKey] = void 0;
      return callback(new Error('Timeout of', _this.sendTimeout, 'msec exceeded'));
    }, this.sendTimeout);
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

  IPCClient.prototype.subscribe = function(connString, channel, subchannel, event, func) {
    var filter, sock, socket,
      _this = this;
    if (_.isFunction(subchannel)) {
      func = subchannel;
      event = '';
      subchannel = '';
    } else if (_.isFunction(event)) {
      func = event;
      event = '';
    }
    socket = this.sockets[channel] = zmq.socket('sub');
    filter = channel || '';
    this.subscriptors[filter] = func;
    socket.on("message", function(message) {
      var data, parts;
      message = message.toString();
      parts = message.split(" ");
      channel = parts[0];
      data = parts[1];
      data = _this.parser.parse(data);
      data.channel = channel;
      return func(data);
    });
    socket.on("error", function(err) {
      return _this.subError(channel, err, func);
    });
    sock = socket.connect(connString);
    return socket.subscribe(filter);
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
