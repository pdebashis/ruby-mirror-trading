require_relative './../lib/5paisa/paisa_connect'
require_relative './../lib/5paisa/paisa_ticker'
require_relative './../lib/simple-feeder'
require_relative './../lib/strategy/mirror'
require 'frappuccino'
require 'logger'
require 'yaml'
require 'websocket-client-simple'
require 'rubyXL'
require 'net/smtp'

### FUNCTIONS
def read_master_client workbook
  master = {}
  master[:client_code] = workbook[0].sheet_data[1][0].value
  workbook[0].each_with_index do |row,index|
    if row[0].value == master[:client_code] and index > 2
      master[:index] = index
      master[:api_key] = row[2].value
      master[:api_secret] = row[3].value
      master[:appsource] = row[4].value
      master[:totp] = row[5].value if row[5]
      master[:mpin] = row[6].value
      master[:userid] = row[7].value
      master[:access_token] = row[8].value if row[8]
      break
    end
  end
  return master 
end

def read_clients workbook
  #[:client_code, :client_name, :api_key, :api_secret, :app_source, :totp, :mpin, :userid, :access_token, :lot_size, :allow_trade]
  master_client = workbook[0].sheet_data[1][0].value
  clients = []
  workbook[0].each_with_index do |row,index|
    client = {}
    unless row[0].value.nil? or index <=2 or row[0].value == master_client
      client[:client_code] = row[0].value
      client[:name] = row[1].value
      client[:api_key] = row[2].value
      client[:api_secret] = row[3].value
      client[:appsource] = row[4].value
      client[:totp] = row[5].value if row[5]
      client[:mpin] = row[6].value
      client[:userid] = row[7].value
      client[:access_token] = row[8].value if row[8]
      client[:holding] = 0
      client[:lot_size] = row[9].value
      client[:trade_flag] = row[10].value
      clients << client
    end
  end
  clients
end

### LOGS AND DISPLAY
window = javax.swing.JFrame.new(__dir__)
window.setDefaultCloseOperation(javax.swing.JFrame::EXIT_ON_CLOSE)
window.setSize 500,600
logs_area = javax.swing.JTextArea.new(20,10)
scroll = javax.swing.JScrollPane.new(logs_area)
window.add(scroll)
window.show

API=Logger.new("#{Dir.pwd}/logs/api.log")
LOG1=Logger.new("#{Dir.pwd}/logs/copy-trading.log", 'weekly', 30)

API.formatter = proc do |severity, datetime, _progname, msg|
  date_format = datetime.getlocal("+05:30").strftime("%Y%m%d %H:%M.%S")
  "[#{date_format}] #{msg}\n"
end

LOG1.formatter  = proc do |severity, datetime, _progname, msg|
    date_format = datetime.getlocal("+05:30").strftime("%Y%m%d %H:%M.%S")
    "[#{date_format}] #{severity.ljust(5)}: #{msg}\n"
end


### MASTER LOGIN CODE
workbook = RubyXL::Parser.parse "#{Dir.pwd}/config/MirrorTradesystem.xlsx"

master = read_master_client(workbook)
API.info master
broker_connect = PaisaConnect.new(master[:api_key],master[:client_code],master[:appsource],API)

unless master[:access_token].nil?
  logs_area.append "Master login from saved token ...\n"
  broker_connect.set_access_token(master[:access_token])
else
  begin
    logs_area.append "Master login with fresh TOTP ...\n"
    login_details=broker_connect.generate_access_token(master[:userid], master[:totp], master[:mpin], master[:api_secret])
  rescue
    logs_area.append "Master Account login failed, Exiting in 100s...\n"
    sleep 100
    exit
  end
end

sleep 2
API.info "Master Access Token below"
API.info broker_connect.access_token

funds = if broker_connect.margins
  broker_connect.margins["NetAvailableMargin"]
else
  {}
end
logs_area.append "Master available fund = #{funds}\n"
logs_area.append "...\n"

copy_accounts = []
accounts=read_clients(workbook)

accounts.each do |client|
  
  broker_connect = PaisaConnect.new(client[:api_key],client[:client_code],client[:appsource],API)

  unless client[:access_token].nil?
    logs_area.append "Copy Account Saved Token ...\n"    
    broker_connect.set_access_token(client[:access_token])
    client[:api] = broker_connect
    copy_accounts << client
    funds=broker_connect.margins["NetAvailableMargin"]
    logs_area.append "#{client[:name]} available fund = #{funds}\n"
  else
    next if client[:totp].nil?
    begin
      logs_area.append "#{client[:name]} Copy Account Fresh Login...\n"
      API.info "Using fresh login flow for #{client[:name]}" 
      login_details=broker_connect.generate_access_token(client[:userid], client[:totp], client[:mpin], client[:api_secret])

      API.info "#{client[:name]} Login Complete" 
      client[:access_token] = broker_connect.access_token
      client[:api] = broker_connect
      API.info broker_connect.access_token
      funds=broker_connect.margins["NetAvailableMargin"]
      logs_area.append "#{client[:name]} available fund = #{funds}\n"

      #broker_connect.place_cnc_order("KOTAKBANK-EQ","BUY", 25, nil, "LIMIT") #######################################
      copy_accounts << client
    rescue
      API.info "#{client[:id]} Client login failed #{login_details}"
      logs_area.append "#{client[:id]} Client login failed...\n"
    end
  end
end

logs_area.append "\nValid Copy Accounts Count = #{copy_accounts.size}\n"

paisa_ticker = PaisaTicker.new(master[:access_token],master[:client_code],API)
feeder1 =  Feeder.new(paisa_ticker,API,logs_area)
StrategyMirror.new(copy_accounts, feeder1, LOG1)
feeder1.start

logs_area.append "GG Well Played, Exiting in 10s...\n"
sleep 10