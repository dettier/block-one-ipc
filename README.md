block-one-ipc
=============

Current version 0.1.8

# Block-One Inter-Process Communication Module.

## Установка

в раздел "dependencies" файла package.json проекта прописать:
```
"block-one-ipc": "git://github.com/dettier/block-one-ipc.git#v0.1.8"
```
и запустить в командной строке 
```npm install```

либо запустить в командной строке
```npm install git://github.com/dettier/block-one-ipc.git#v0.1.8```

## Подключение

Для подключения к ядру во-первых необходимо в коде подключить модуль ExchangeClient
Данный модуль инкапсулирует клиентскую часть паттерна RPC на основе ZeroMQ (для вызова серверных процедур), паттерна подписки на броадкаст-раздачи (для получения потоков заявок и сделок) и подписки на heartbeat-сообщения ядра.

### Для клиентского приложения  
```IpcClient = require('block-one-ipc').IpcClient```

После чего необходимо создать экземпляр клиента:
```
ipAddress = someAddress   
port = somePort   
subscriptionPort = someSubPort   

client = new IpcClient("tcp://#{someAddr}:#{somePort}", "tcp://#{someAddr}:#{subscriptionPort}")
```
Будет возвращен готовый экземпляр клиента, то есть далее можно вызывать клиентские методы, например, реализующие RPC-паттерн:
```
args = {
   someArg : 11
   otherArg : "2222"
   anotherArg : ['3', '4', '5']
}
client.invoke 'some_server_proc', args, (err, result) ->
    #handle server response...
```  


### Для серверного приложения  
```IpcServer = require('block-one-ipc').IpcServer```

после чего создать серверный контекст процедур:
```
context = {
    myProc : (ctx, args, callback) ->
       #do something
       callback? null, result
    myOtherProc : (ctx, args, callback) ->
       #do anything
       if something_wrong
           callback? 'something wrong'
       callback? null, 'ok'
}
```
создать экземпляр сервера:
```
server = new IpcServer context
```
модуль зарегистрирует процедуры контекста, после чего можно выполнить привязку к адресу по умолчанию (`tcp://localhost:17077`):
```
server.bind()
```
или к конкретному адресу:
```
server.bind('tcp://111.22.33.44:8833')
server.bind('ipc://ipc-server-for-some-data')
```
Сервер запускает внутренний цикл работы, "слушая" сокеты на указанных адресах и, вызывая процедуры, зарегистрированные в контексте по запросам от IpcClient-ов.  

## Подписка на потоки

В клиентском приложении выполнить подписку можно следующим образом:
```
client.subscribe 'stream_name', (data) ->
    #do something with a data
```

## Вызов серверных процедур

Серверные процедуры вызываются с клиента следующим образом:

```
params = { accountId [, optional_params]}
client.invoke 'proc_name', params, (err, result) ->
    if err?
        someErrorHandling err
    doSomethingWithResult result
```
Первый аргумент метода `invoke` - название функции (описаны далее), 
второй аргумент - объект, содержащий в обязательном порядке поле accountId для идентификации в ядре пользователя, от имени которого выполняется запрос, и ряд параметров, состав и формат которых описан далее.
Третьим аргументом передается колбэк, который исполняется при получении ответа от сервера, либо по тайм-ауту при отсутствии связи. 
В аргумент `err` передается ошибка (м.б. как логическая, так и низкоуровневая физическая), а в аргумент `result` - результат обработки запроса на сервере. Ошибки и результаты для каждой и процедур сервера описаны в следующем разделе.

Все потенциально нецелочисленные параметры, такие как цена и количество, должны передаваться в виде строк для избежания ошибок округления при сериализации/десериализации и последующих мат. операциях.
