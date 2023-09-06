require 'websocket-client-simple'
require 'json'
socket_url = "wss://openfeed.5paisa.com/Feeds/api/chat?Value1=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1bmlxdWVfbmFtZSI6IjUzNTcwMDkzIiwicm9sZSI6IjE3NzIyIiwiU3RhdGUiOiIiLCJSZWRpcmVjdFNlcnZlciI6IkMiLCJuYmYiOjE2OTM5NzUzMjAsImV4cCI6MTY5NDAyNDk5OSwiaWF0IjoxNjkzOTc1MzIwfQ.AuIwxKnHKQmD27JGMA8D_bbsZYsN18g0q3WjpIKDsLM|53570093"
ws = WebSocket::Client::Simple.connect socket_url
ws.on :open do puts "Connected" end
ws.on :error do puts "Error" end
ws.on :message do |msg| puts msg end
ws.on :close do puts "close!" end