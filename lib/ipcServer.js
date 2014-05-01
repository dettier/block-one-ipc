var FuncsToTypes, IPCServer, MessageTypes, TypesToFuncs, cron, defaultPort, defaultPubPort, zmq, _;

zmq = require('zmq');

cron = require('cron');

_ = require('lodash');

MessageTypes = require('./message-enums').Types;

TypesToFuncs = require('./message-enums').TypesToFuncs;

FuncsToTypes = require('./message-enums').FuncsToTypes;

defaultPort = '17077';

defaultPubPort = '17088';

IPCServer = (function() {
  function IPCServer(serverContext, options, parser, hbSeconds) {
    var _this = this;
    this.serverContext = serverContext;
    this.options = options;
    this.parser = parser != null ? parser : JSON;
    this.hbSeconds = hbSeconds != null ? hbSeconds : 2;
    this.clients = {};
    this.socket = zmq.socket('rep');
    this.heartbeatCnt = 0;
    this.pubSockets = {};
    this.existingAddresses = {};
    this.statelessMessageTypes = _.keys(TypesToFuncs);
    if (this.hbSeconds != null) {
      if (this.hbSeconds > 60) {
        this.hbSeconds = 60;
      }
      new cron.CronJob("*/" + this.hbSeconds + " * * * * *", (function() {
        return _this.heartbeat();
      }), null, true);
    }
    this.socket.on("message", function(req) {
      return _this.message(req);
    });
    this.socket.on("error", function(error) {
      return _this.error(error);
    });
  }

  IPCServer.prototype.getClientContext = function(clientId) {
    var ctx;
    if (!this.clients[clientId]) {
      ctx = {
        counter: -1,
        id: clientId
      };
      this.clients[clientId] = ctx;
    }
    return this.clients[clientId];
  };

  IPCServer.prototype.register = function(ctx, clientId, callback) {
    var clientContext;
    clientContext = this.getClientContext(clientId);
    return typeof callback === "function" ? callback(null, clientContext) : void 0;
  };

  IPCServer.prototype.message = function(message) {
    var ctx, func,
      _this = this;
    message = JSON.parse(message.toString());
    ctx = this.getClientContext(message.clientId);
    func = this.serverContext[message.func];
    if (!_.isFunction(func)) {
      return this.reply(message.id, message.func, message.type + 1, message["arguments"], 'action not registered');
    }
    return func(ctx, message["arguments"], function(error, result) {
      return _this.reply(message.id, message.func, message.type + 1, message["arguments"], error, result);
    });
  };

  IPCServer.prototype.error = function(error) {
    return console.log(error);
  };

  IPCServer.prototype.heartbeat = function() {
    var hb, result;
    if (this.heartbeatCnt + 1 > 0xffffffff) {
      this.heartbeatCnt = 0;
    }
    hb = {
      type: 1,
      cnt: this.heartbeatCnt++
    };
    return result = this.publish('heartbeat', '', 'hb', hb);
  };

  IPCServer.prototype.publish = function(channel, subchannel, event, data) {
    var message, sockets;
    data = this.parser.stringify(data);
    message = (channel || '') + ' ' + data;
    sockets = this.pubSockets[channel];
    return _.forEach(sockets, function(socket) {
      return socket.send(message);
    });
  };

  IPCServer.prototype.reply = function(id, funcName, type, args, error, result) {
    var reply;
    if (type == null) {
      type = MessageTypes.InvokeSyncReply;
    }
    if (error == null) {
      error = null;
    }
    if (result == null) {
      result = void 0;
    }
    reply = {
      type: type,
      id: id,
      func: funcName,
      error: error,
      res: result
    };
    if (this.statelessMessageTypes.indexOf(type.toString()) >= 0) {
      reply.args = args;
    }
    reply = this.parser.stringify(reply);
    return this.socket.send(reply);
  };

  IPCServer.prototype.bind = function(type, address, port) {
    var string;
    if (type == null) {
      type = 'tcp';
    }
    if (address == null) {
      address = '127.0.0.1';
    }
    if (port == null) {
      port = defaultPort;
    }
    if (!_.isString(address)) {
      return false;
    }
    if (type === 'tcp') {
      string = "" + type + "://" + address + ":" + port;
    } else {
      string = "" + type + "://" + address;
    }
    return this.socket.bindSync(string);
  };

  IPCServer.prototype.createPubChannel = function(channel, type, address, port) {
    var addrs, socket, sockets, string, _base, _base1;
    if (type == null) {
      type = 'tcp';
    }
    if (address == null) {
      address = '127.0.0.1';
    }
    if (port == null) {
      port = defaultPubPort;
    }
    if (type === 'tcp') {
      string = "" + type + "://" + address + ":" + port;
    } else {
      string = "" + type + "://" + address;
    }
    addrs = (_base = this.existingAddresses)[channel] != null ? (_base = this.existingAddresses)[channel] : _base[channel] = [];
    if (addrs[string] != null) {
      return;
    }
    this.existingAddresses[channel].push(string);
    sockets = (_base1 = this.pubSockets)[channel] != null ? (_base1 = this.pubSockets)[channel] : _base1[channel] = [];
    socket = zmq.socket('pub');
    socket.bindSync(string);
    sockets.push(socket);
    return this.pubSockets[channel] = sockets;
  };

  return IPCServer;

})();

module.exports = IPCServer;
