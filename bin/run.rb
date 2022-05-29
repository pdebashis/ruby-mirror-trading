require_relative './../lib/kite/kite_connect'
require_relative './../lib/fyer/fyer_connect'
require_relative './../lib/angel/angel_connect'
require_relative './../lib/kite/kite_ticker'
require_relative './../lib/simple-feeder'
require_relative './../lib/strategy/mirror'
require 'frappuccino'
require 'logger'
require 'yaml'
require 'websocket-client-simple'
require 'rubyXL'

### FUNCTIONS
def read_master_client workbook
  master = {}
  master[:client] = workbook[0].sheet_data[1][0].value
  workbook[0].each_with_index do |row,index|
    if row[0].value == master[:client] and index > 2
      master[:index] = index
      master[:api_key] = row[2].value
      master[:api_secret] = row[3].value
      master[:request_token] = row[5].value
      master[:access_token] = row[6].value
      master[:fyer] = true if master[:api_key] =~ /-/
      master[:angel] = true if master[:request_token] == master[:client]
      break
    end
  end
  return master 
  #[:api_key, :api_secret, :access_token, :request_token, :lot_size, :index]
end

def read_clients workbook
  master = workbook[0].sheet_data[1][0].value
  clients = []
  workbook[0].each_with_index do |row,index|
    client = {}
    unless row[0].value.nil? or index <=2 or row[0].value == master
      client[:client] = row[0].value
      client[:id] = row[1].value
      client[:api_key] = row[2].value
      client[:api_secret] = row[3].value
      client[:request_token] = row[5].value
      client[:access_token] = row[6].value
      client[:holding] = 0
      client[:lot_size] = row[7].value
      client[:trade_flag] = row[8].value
      client[:fyer] = true if client[:api_key] =~ /-/
      client[:angel] = true if client[:request_token] == client[:client]
      clients << client
    end
  end
  clients
end

### LOGS AND DISPLAY
window = javax.swing.JFrame.new(__dir__)
window.setSize 500,600
logs_area = javax.swing.JTextArea.new(20,10)
scroll = javax.swing.JScrollPane.new(logs_area)
window.add(scroll)
window.show
logs_area.set_text("Starting the system...\n")

API=Logger.new("#{Dir.pwd}/logs/api.log")
LOG1=Logger.new("#{Dir.pwd}/logs/copy-trading.log", 'weekly', 30)

API.formatter = proc do |severity, datetime, _progname, msg|
  date_format = datetime.getlocal("+05:30").strftime("%Y-%m-%d %H:%M:%S")
  "[#{date_format}] #{msg}\n"
end

LOG1.formatter  = proc do |severity, datetime, _progname, msg|
    date_format = datetime.getlocal("+05:30").strftime("%Y-%m-%d %H:%M:%S")
    "[#{date_format}] #{severity.ljust(5)}: #{msg}\n"
end


### MASTER LOGIN CODE
workbook = RubyXL::Parser.parse "#{Dir.pwd}/config/MirrorTradesystem.xlsx"

master = read_master_client(workbook)
API.info master
broker_connect = KiteConnect.new(master[:api_key],API)
if master[:fyer]
  broker_connect = FyerConnect.new(master[:api_key],API)
end
if master[:angel]
  broker_connect = AngelConnect.new(master[:api_key],API)
end

unless master[:access_token].nil?
  logs_area.append "Master Account Saved Token ...\n"
  broker_connect.set_access_token(master[:access_token])
else
  begin
    logs_area.append "Master Account Fresh Login ...\n"
    login_details=broker_connect.generate_access_token(master[:request_token], master[:api_secret])
  rescue
    logs_area.append "Master Account login failed, Exiting in 100s...\n"
    sleep 100
    exit
  end
end

sleep 2

master[:access_token] = broker_connect.access_token
API.info "Master Access Token below"
API.info master[:access_token]

if master[:fyer]
  margins = broker_connect.margins["fund_limit"] 
  funds = margins ? margins.select{ |x| x["id"] == 10 }[0]["equityAmount"] : 0
  logs_area.append "Master available #{funds}\nFyer Master Account Not supported yet\n"
  logs_area.append "GG Well Played, Exiting in 100s...\n"
  sleep 100
  exit
elsif master[:angel]
  margins = broker_connect.profile
  funds = margins["data"]["net"]
  logs_area.append "Master available #{funds}\nAngel Master Account Not supported yet\n"
  logs_area.append "GG Well Played, Exiting in 100s...\n"
  sleep 100
  exit
else
  d = broker_connect.margins || {}
  funds=d["equity"]["available"]["live_balance"] if d["equity"]
  logs_area.append "Master available #{funds}\n"
end

kite_ticker = KiteTicker.new(master[:access_token],master[:api_key],API)
feeder1 = Feeder.new(kite_ticker,API,logs_area)

copy_accounts = []
accounts=read_clients(workbook)

accounts.each do |client|
  
  if client[:fyer]
    broker_connect = FyerConnect.new(client[:api_key],API)
  elsif client[:angel]
    broker_connect = AngelConnect.new(client[:api_key],API)
  else
    broker_connect = KiteConnect.new(client[:api_key],API)
  end

  unless client[:access_token].nil?
    logs_area.append "Copy Account Saved Token ...\n"    
    broker_connect.set_access_token(client[:access_token])
    client[:api] = broker_connect
    copy_accounts << client
    funds=broker_connect.margins["equity"]["available"]["live_balance"]
    logs_area.append "#{client[:id]} available #{funds}\n"
  else
    next if client[:request_token].nil?
    begin
      logs_area.append "#{client[:id]} Copy Account Fresh Login...\n"
      API.info "Using fresh login flow for #{client[:id]}" 
      login_details=broker_connect.generate_access_token(client[:request_token], client[:api_secret])

      if client[:fyer]
        API.info "Fyer Flow" 
        margins = broker_connect.margins["fund_limit"] 
        funds = margins ? margins.select{ |x| x["id"] == 10 }[0]["equityAmount"] : 0
        logs_area.append "#{client[:id]} available #{funds}\n"
      elsif client[:angel]
        API.info "Angel Flow" 
        margins = broker_connect.profile
        funds = margins["data"]["net"]
        logs_area.append "#{client[:id]} available #{funds}\n"
      else
        API.info "Kite Flow" 
        funds=broker_connect.margins["equity"]["available"]["live_balance"]
        logs_area.append "#{client[:id]} available #{funds}\n"
      end

      API.info client[:id]
      API.info broker_connect.access_token
      client[:access_token] = broker_connect.access_token
      client[:api] = broker_connect
      #broker_connect.place_cnc_order("KOTAKBANK-EQ","BUY", 25, nil, "LIMIT") #######################################
      copy_accounts << client
    rescue
      API.info "#{client[:id]} Client login failed #{login_details}"
      logs_area.append "#{client[:id]} Client login failed...\n"
    end
  end
end

logs_area.append "\nValid Copy Accounts Count = #{copy_accounts.size}\n"

StrategyMirror.new(copy_accounts, feeder1, LOG1)

feeder1.start

logs_area.append "GG Well Played, Exiting in 10s...\n"
sleep 10