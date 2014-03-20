var IPCServer, cron, zmq, _;

zmq = require('zmq');

cron = require('cron');

_ = require('lodash');

IPCServer = (function() {
  function IPCServer(serverContext, options, parser, hbSeconds) {
    var _this = this;
    this.serverContext = serverContext;
    this.options = options;
    this.parser = parser != null ? parser : JSON;
    this.hbSeconds = hbSeconds != null ? hbSeconds : 2;
    this.clients = {};
    this.socket = zmq.socket('rep');
    if (this.hbSeconds != null) {
      this.heartbeatCnt = 0;
      this.heartbeatSocket = zmq.socket('pub');
      new cron.CronJob("*/" + this.hbSeconds + " * * * * *", (function() {
        return _this.heartbeat();
      }), null, true);
    }
    this.socket.on("message", function(reply) {
      return _this.message(reply);
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
      return this.reply(message.id, message.func, 'action not registered');
    }
    return func(ctx, message["arguments"], function(error, result) {
      return _this.reply(message.id, message.func, error, result);
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
    hb = this.parser.stringify(hb);
    return result = this.heartbeatSocket.send(hb);
  };

  IPCServer.prototype.reply = function(id, funcName, error, result) {
    var reply;
    if (error == null) {
      error = null;
    }
    if (result == null) {
      result = void 0;
    }
    reply = {
      type: 2,
      id: id,
      func: funcName,
      error: error,
      res: result
    };
    reply = this.parser.stringify(reply);
    return this.socket.send(reply);
  };

  IPCServer.prototype.bind = function(type, address, port) {
    var hbPort, hbString, string;
    if (type == null) {
      type = 'tcp';
    }
    if (address == null) {
      address = '127.0.0.1';
    }
    if (port == null) {
      port = '17077';
    }
    if (!_.isString(address)) {
      return false;
    }
    string = "" + type + "://" + address + ":" + port;
    this.socket.bindSync(string);
    hbPort = parseInt(port) + 1;
    hbString = "" + type + "://" + address + ":" + hbPort;
    return this.heartbeatSocket.bindSync(hbString);
  };

  IPCServer.prototype.bindPub = function() {};

  return IPCServer;

})();

module.exports = IPCServer;
