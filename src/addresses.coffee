# ipc protocol supported only in systems which supports POSIX domain sockets 
module.exports =
    orderbook   : 
        ipc :  address : "block-one-orderbook.ipc"
        tcp :  address : '*', port : '17080' 

    deals       : 
        ipc : address : "block-one-deals.ipc"
        tcp : address : "*", port : '17081'

    history     :   
        ipc : address : "block-one-history.ipc"
        tcp : address : "*", port : '17082'

    heartbeat   :
        ipc : address : "block-one-core.ipc"
        tcp : address : "*", port : '17083'

    accounts    :
        ipc : address : "block-one-accounts.ipc"
        tcp : address : "*", port : '17084' 


    