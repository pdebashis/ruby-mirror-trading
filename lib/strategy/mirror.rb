class StrategyMirror
  def initialize copy_accounts, feeder, logger=nil
	  @feeder = feeder
	  @users = copy_accounts
    Frappuccino::Stream.new(feeder).
    select{ |event| event.has_key?(:dict) && !event[:dict].nil? }.
    on_value(&method(:on_data))

    @logger = logger
    @report_name = Dir.pwd+"/logs/trades.log"
    unless File.exist?(@report_name)
      reporting "TIMESTAMP,IDENTIFIER,USER,STATUS,ORDER_ID,EXCHANGE,SYMBOL,INSTRUMENT,AT_MARKET,TRANSACTION,EXCHANGE_TYPE,QUANTITY,PRICE,TRIGGER-PRICE"
    end
    
    @symbol_lot_size = 15
    @x_times = 1
   
  end

  def on_data dict
    data = dict[:dict]
    workbook = RubyXL::Parser.parse "#{Dir.pwd}/config/MirrorTradesystem.xlsx"
    algo_switch = workbook[0].sheet_data[1][2].value
    dyn_master_switch = workbook[0].sheet_data[1][1].value
	
    o_type = data[:type]
    o_id = data[:order_id]
    acc = data[:account]
    status = data[:status]
    exchange = data[:exchange]
    exchange_type = data[:exchange_type]
    symbol = data[:t_symbol]
    instrument = data[:t_instrument]
    at_market = data[:at_market]
    t_type = data[:t_type]
    #validity = data[:validity]
    quantity = data[:quantity].to_i
    price = data[:price]
    #trigger_price = data[:trigger_price]

    #find_symbol = @all_data.filter { |x| x["symbol"].match?(symbol) && x["lotsize"] != "-1"}.first
    #@symbol_lot_size = find_symbol["lotsize"].to_i unless find_symbol.nil?
    
    if symbol.include? "BANKNIFTY"
      @symbol_lot_size = 15 
    else
      @symbol_lot_size = 50
    end
    @x_times = quantity/@symbol_lot_size

    # @logger.info "Master #{t_type} #{@x_times}x lotsize (#{@symbol_lot_size})"
    @logger.info "Master recieved #{status} (market : #{at_market}) #{t_type} #{quantity} (lots multiplier : #{@x_times})"
    reporting "MASTER,#{acc},#{status},#{o_id},#{exchange},#{symbol},#{instrument},#{at_market},#{t_type},#{exchange_type},#{quantity},#{price}"

    if status.upcase == "PLACED" and algo_switch == "ON" and at_market == "Y" and o_type == "P"
      place_order symbol,instrument,t_type,dyn_master_switch,exchange_type
    end

    # if status == "OPEN" and validity == "DAY" and algo_switch == "ON" and type == "LIMIT"
    #   limit_order symbol,t_type,dyn_master_switch,type,product,price,trigger_price,o_id
    # end

    # if status == "CANCELLED" and validity == "DAY" and algo_switch == "ON" and (type == "LIMIT" or type == "SL")
    #   cancel_order symbol,t_type,type,price,trigger_price,o_id
    # end

    # if status == "TRIGGER PENDING" and validity == "DAY" and algo_switch == "ON" and type == "SL"
    #   limit_order symbol,t_type,dyn_master_switch,type,product,price,trigger_price,o_id
    # end

    # if status.upcase == "MODIFIED" and algo_switch == "ON" and o_type == "M"
    #   modify_order symbol,t_type,dyn_master_switch,type,product,price,trigger_price,o_id
    # end

  end

  def reporting msg
    date_format = Time.now.getlocal("+05:30").strftime("%Y-%m-%d %H:%M:%S")
    if File.exist?(@report_name)
      File.open(@report_name,"a+") do |op|
        op << "#{date_format},#{msg}\n"
      end
    else
      File.open(@report_name,"a+") do |op|
        op << "#{msg}\n"
      end
    end
  end

  def place_order symbol,instrument,t_type,dyn_master_switch,e_type
    refresh_users
    @logger.info "Placing Order #{t_type} #{symbol}"

    @users.each do |usr|
      next if usr[:trade_flag] == "NO"
      api_usr = usr[:api]
      lot_size = usr[:lot_size] * @symbol_lot_size
      lot_size = usr[:lot_size] * @x_times * @symbol_lot_size if dyn_master_switch == "ON"
      lot_size = lot_size * usr[:holding] if t_type == "S" and dyn_master_switch == "OFF"
      api_usr.place_custom_order(instrument,t_type, lot_size, e_type, 0, 0)
      
      reporting "COPY,#{usr[:name]},INITIATED,,,#{symbol},#{instrument},Y,#{t_type},#{e_type},#{lot_size},0,0"

      @logger.debug "Current holding #{usr[:holding]}"
      if t_type == "B"
        usr[:holding] += 1
      elsif t_type == "S"
        usr[:holding] = 0
      end
      @logger.debug "Updated holding #{usr[:holding]}"
    end

  end

  def cancel_order symbol,t_type,o_type,price,trigger_price,o_id
    @logger.info "Cancelling Order #{o_id}"
    @users.each do |usr|
      api_usr = usr[:api]
      id_to_cancel = usr[o_id]
      api_usr.cancel_order(id_to_cancel) unless id_to_cancel.nil?
      usr[o_id] = nil
      
      #USR[:holding] not updated for cancel order 
      reporting "COPY,#{usr[:id]},CANCELLED,,#{id_to_cancel},,,#{symbol},,#{o_type},#{t_type},,,,#{price},#{trigger_price}" unless id_to_cancel.nil?
    end

  end

  def limit_order symbol,t_type,dyn_master_switch,o_type,p_type,price,t_price,o_id
    @logger.info "Placing Order LIMIT #{t_type} #{symbol}"
    refresh_users

    @users.each do |usr|
      next if usr[:trade_flag] == "NO"
      api_usr = usr[:api]
      lot_size = usr[:lot_size] * @symbol_lot_size
      lot_size = usr[:lot_size] * @x_times * @symbol_lot_size if dyn_master_switch == "ON"
      lot_size = lot_size * usr[:holding] if t_type == "SELL" and dyn_master_switch == "OFF"

      if usr[o_id]
        api_usr.modify_order(usr[o_id], lot_size, o_type,price,t_price,symbol,p_type)
        reporting "COPY,#{usr[:id]},UPDATED,,#{usr[o_id]},,,#{symbol},,#{o_type},#{t_type},,#{p_type},#{lot_size},#{price},#{t_price}"
      else
        resp = api_usr.place_custom_order(symbol,t_type, lot_size, price, o_type,p_type,t_price)
        usr[o_id] = resp unless resp.nil?
        reporting "COPY,#{usr[:id]},INITIATED,,#{usr[o_id]},,,#{symbol},,#{o_type},#{t_type},,#{p_type},#{lot_size},#{price},#{t_price}"
      end

      @logger.debug "Update holding #{usr[:holding]}"

      if t_type == "BUY"
        usr[:holding] += 1
      elsif t_type == "SELL"
        usr[:holding] = 0
      end

      @logger.debug "Updated holding #{usr[:holding]}"
    end

  end

  def refresh_users
    new_values = {}
    
    workbook = RubyXL::Parser.parse "#{Dir.pwd}/config/MirrorTradesystem.xlsx"
    workbook[0].each_with_index do |row,index|
      unless row.nil? or row[0].nil? or row[0].value.nil? or index <=2
        client = row[0].value
        lot_size = row[9].value
        new_values[client] = lot_size
      end
    end

    @logger.info "refreshed users lot size from excel = #{new_values}"

    @users.each do |usr|
      unless new_values[usr[:client_code]].nil?
        usr[:lot_size] = new_values[usr[:client_code]]
      end
    end
    @logger.debug @users
  end
end
