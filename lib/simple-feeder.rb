class Feeder

    def initialize (ticker, logger=nil, display=nil)
      @ticker = ticker
      @logger = logger
      @display = display
      me = self
      @ws = WebSocket::Client::Simple.connect ticker.socket_url

      @ws.on :open do
        logger.info "WebSocket connection opened"
      end

      @ws.on :error do |e|
        puts "Inside WS Error #{e}"
        logger.debug "Inside WS Error #{e}"
        sleep 2
      end

      @ws.on :close do
        logger.info "close!"
      end

      @ws.on :message do |msg|
        puts "Received MESSAGE"
        socket_data = ticker.make_sense( msg )
        if msg.is_a?(WebSocket::Frame::Incoming::Client)
          puts msg
          json_obj = JSON.parse( socket_data )
          me.fetch json_obj
        end
      end
    end
  
    def start
      @logger.info "Feeder Started with #{@ticker.socket_url}"
      @display.append "Feeder Started...\n"
      sleep 2

      loop do
        return unless @ws.open?   
        
        sleep 60

        @ws.send("Ping")
        ###TEST####
        # buy_market = {"ReqType"=>"P", "ClientCode"=>"53570093", "Exch"=>"N", "ExchType"=>"D", "ScripCode"=>44576, "Symbol"=>"BANKNIFTY 13 Sep 2023 CE 47000.00", "Series"=>"", "BrokerOrderID"=>935005426, "ExchOrderID"=>"1500000068694778", "ExchOrderTime"=>"2023-09-11 13:44:19", "BuySell"=>"B", "Qty"=>15, "Price"=>0, "ReqStatus"=>0, "Status"=>"Placed", "OrderRequestorCode"=>"53570093", "AtMarket"=>"Y", "Product"=>"D", "WithSL"=>"N", "SLTriggerRate"=>0, "DisclosedQty"=>0, "PendingQty"=>15, "TradedQty"=>0, "RemoteOrderId"=>"5357009320230911014418525", "Remark"=>""}
        
        # self.fetch buy_market
        ########### 
      end
    end

    def fetch json_data
      puts "Inside Fetch"
      API.info "Inside Fetch : #{json_data}"

      if json_data.is_a?(Array)
        puts json_data
        return
      end

      puts json_data
      
      d={
        type: json_data["ReqType"],
        account: json_data["ClientCode"],
        order_id: json_data["RemoteOrderId"],
        status: json_data["Status"],
        exchange: json_data["Exch"],
        exchange_type: json_data["ExchType"],
        t_symbol: json_data["Symbol"],
        t_instrument: json_data["ScripCode"],
        at_market: json_data["AtMarket"],
        t_type: json_data["BuySell"],
        #validity: json_obj["data"]["validity"],
        quantity: json_data["Qty"],
        #trigger_price: json_obj["data"]["trigger_price"],
        price: json_data["Price"]
      }

      @display.append "#{d[:status].split.first}\t#{d[:t_symbol].split.first}-#{d[:t_symbol].split[-2]}-#{d[:t_symbol].split.last}\t#{d[:t_type]}\t#{d[:price]} (#{d[:quantity]})\n"
      emit dict: d
    end
    
    def close_ws
      @logger.info "signal:close received"
      @ws.close
    end
    
    def subscribe(token=15083)
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
        @ws.send(d.to_json)
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
        @ws.send(d.to_json)
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
  
  