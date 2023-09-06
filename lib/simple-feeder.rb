class Feeder

    def initialize (ticker, logger=nil, display=nil)
      @ticker = ticker
      @logger = logger
      @display = display
      me = self
      @ws = WebSocket::Client::Simple.connect @ticker.socket_url

      @ws.on :open do 
        logger.info "Connected"
      end

      @ws.on :error do |e|
        puts "Inside WS Error"
        logger.info e
      end

      @ws.on :close do
        puts "Inside WS Close"
        logger.info "close!"
      end

      @ws.on :message do |msg|
        socket_feed = ticker.make_sense( msg )
        me.fetch socket_feed.data if msg.class.name == "WebSocket::Frame::Incoming::Client"
      end
    end
  
    def start
      @logger.info "Feeder Started with #{@ticker.socket_url}"
      @display.append "Feeder Started...\n"
      sleep 5

      loop do
        return unless @ws.open?
        puts "still connected"
        sleep 10
      end
    end

    def fetch json_obj
      puts "Inside Fetch"
      json_data = JSON.parse(json_obj)
      puts json_data

      return unless json_data["ReqType"]
      
      d={
        type: json_data["ReqType"],
        account: json_data["ClientCode"],
        order_id: json_data["RemoteOrderId"],
        status: json_data["Status"],
        exchange: json_data["Exch"],
        o_time: json_data["ExchTradeTime"],
        t_symbol: json_data["Symbol"],
        t_instrument: json_data["ScripCode"],
        order_type: json_data["Series"],
        t_type: json_data["BuySell"],
        #validity: json_obj["data"]["validity"],
        product: json_data["Product"],
        quantity: json_data["OrderQty"],
        #trigger_price: json_obj["data"]["trigger_price"],
        price: json_data["Price"]
      }

      @display.append "#{d[:status]}\t#{d[:t_symbol].split.first}\t#{d[:t_type]}\t#{d[:price]} (#{d[:quantity]}) \n"
      #emit dict: d
    end
    
    def close_ws
      @logger.info "signal:close received"
      @ws.close
    end
    
    def subscribe(token=15083)
    puts "inside Subscribe"
      begin
        d = {
          "Method": "MarketFeedV3",
          "Operation": "Subscribe",
          "ClientCode": @ticker.client_code,
          "MarketFeedData": [
            {
              "Exch": "N",
              "ExchType": "C",
              "ScripCode": token
            }
          ]
        }
        puts d
        @ws.send(d.to_json.to_s)
      rescue
        return false
      end
    end
  
    def unsubscribe (token=15083)
      begin
        d = {
          "Method": "MarketFeedV3",
          "Operation": "UnSubscribe",
          "ClientCode": @ticker.client_code,
          "MarketFeedData": [
            {
              "Exch": "N",
              "ExchType": "C",
              "ScripCode": token
            }
          ]
        }
        @ws.send(d.to_json.to_s)
      rescue
        return false
      end
    end
  
    def set_mode (mode,token)
      return false unless MODES.include? mode
  
      begin
        d = {a: "mode", v: [mode,[token.to_i]]}
        @ws.send(d.to_json.to_s)
      rescue
        return false
      end
    end
  end
  
  