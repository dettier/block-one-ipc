var FuncsToTypes, Types, TypesToFuncs, _;

_ = require('lodash');

Types = {
  Heartbeat: 1,
  InvokeSyncRequest: 2,
  InvokeSyncReply: 3,
  ChargeRequest: 4,
  ChargeReply: 5,
  WithdrawRequest: 6,
  WithdrawReply: 7
};

module.exports.Types = Types;

TypesToFuncs = {};

TypesToFuncs[Types.ChargeRequest] = 'charge';

TypesToFuncs[Types.ChargeReply] = 'charge';

TypesToFuncs[Types.WithdrawRequest] = 'withdraw';

TypesToFuncs[Types.WithdrawReply] = 'withdraw';

module.exports.TypesToFuncs = TypesToFuncs;

FuncsToTypes = {};

FuncsToTypes.charge = Types.ChargeRequest;

FuncsToTypes.withdraw = Types.WithdrawRequest;

module.exports.FuncsToTypes = FuncsToTypes;
