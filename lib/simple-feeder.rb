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
        logger.info e
      end

      @ws.on :close do
        logger.info "close!"
      end

      @ws.on :message do |msg|
        socket_feed = ticker.make_sense( msg.data )
        me.fetch socket_feed unless msg.type == :binary
      end

      @today = Time.now.getlocal("+05:30").strftime "%Y:%m:%d"
      @d1=Time.strptime("09:00 +05:30","%H:%M %Z")
      @d2=Time.strptime("15:45 +05:30","%H:%M %Z")
    end
  
    def start
      @logger.info "Feeder Started with #{@ticker.socket_url}"
      @display.append "Feeder Started...\n"
      sleep 5

      loop do
        return unless @ws.open?
        # sleep 5 ##########################################################################
        # fetch "test data" ################################################################
      end
    end

    def fetch str
      if str == "test data"
        sleep 5
        buy1={
          type: "order",
          account: "FWU918",
          status: "OPEN",
          exchange: "NFO",
          o_time: "2021-01-11 10:17:35",
          t_symbol: "BANKNIFTY2260235700PE",
          t_instrument: 13017858,
          order_type: "SL",
          t_type: "BUY",
          validity: "DAY",
          product: "NRML",
          message: "abcdef",
          quantity: 25,
          price: 10,
          trigger_price: 5
        }
        @display.append "Buy1 initiated\n"
        emit dict: buy1
        
        sleep 5
        buy2={
          type: "order",
          account: "FWU918",
          status: "OPEN",
          exchange: "NFO",
          o_time: "2021-01-11 10:17:35",
          t_symbol: "BANKNIFTY2260235700PE",
          t_instrument: 13017858,
          order_type: "SL",
          t_type: "BUY",
          validity: "DAY",
          product: "MIS",
          message: "abcdef",
          quantity: 25,
          price: 20,
          trigger_price: 25
        }
        @display.append "Buy2 initiated\n"
        emit dict: buy2
        
        sleep 5
        sell1={
          type: "order",
          account: "FWU918",
          status: "OPEN",
          exchange: "NFO",
          o_time: "2021-01-11 10:17:35",
          t_symbol: "BANKNIFTY2260235700PE",
          t_instrument: 13017858,
          order_type: "MARKET",
          t_type: "SELL",
          validity: "DAY",
          product: "NRML",
          message: "abcdef",
          quantity: 25,
          price: 0,
          trigger_price: 0
        }
        @display.append "Sell1 initiated\n"
        emit dict: sell1
        
        sleep 5
        sell2={
          type: "order",
          account: "FWU918",
          status: "OPEN",
          exchange: "NFO",
          o_time: "2021-01-11 10:17:35",
          t_symbol: "BANKNIFTY2260235700PE",
          t_instrument: 13017858,
          order_type: "MARKET",
          t_type: "SELL",
          validity: "DAY",
          product: "MIS",
          message: "abcdef",
          quantity: 25,
          price: 0,
          trigger_price: 0
        }
        @display.append "Sell2 initiated\n"
        emit dict: sell2
        
        return
      end

      json_obj = JSON.parse(str)
      @logger.info json_obj
      d={
        type: json_obj["type"],
        account: json_obj["data"]["account_id"],
        order_id: json_obj["data"]["order_id"],
        status: json_obj["data"]["status"],
        exchange: json_obj["data"]["exchange"],
        o_time: json_obj["data"]["order_timestamp"],
        t_symbol: json_obj["data"]["tradingsymbol"],
        t_instrument: json_obj["data"]["instrument_token"],
        order_type: json_obj["data"]["order_type"],
        t_type: json_obj["data"]["transaction_type"],
        validity: json_obj["data"]["validity"],
        product: json_obj["data"]["product"],
        message: json_obj["data"]["status_message"],
        quantity: json_obj["data"]["quantity"],
        price: json_obj["data"]["price"],
        trigger_price: json_obj["data"]["trigger_price"]
      }
      @display.append "#{d[:status]}\t#{d[:t_symbol]}\t#{d[:order_type]}\t#{d[:t_type]}\n"

      emit dict: d
    end
    
    def close_ws
      @logger.info "signal:close received"
      @ws.close
    end
  end
  
  