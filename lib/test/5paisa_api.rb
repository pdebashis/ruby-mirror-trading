require 'websocket-client-simple'
require 'json'
socket_url = "wss://openfeed.5paisa.com/Feeds/api/chat?Value1=<token>|<client>"
ws = WebSocket::Client::Simple.connect socket_url
ws.on :open do puts "Connected" end
ws.on :error do puts "Error" end
ws.on :message do |msg| puts msg end
ws.on :close do puts "close!" end

a= {"Method":"MarketFeedV3","Operation":"Subscribe", "ClientCode":"ABC123","MarketFeedData":[ {"Exch":"N","ExchType":"C","ScripCode":15083} ]}
ws.send(a.to_json)
