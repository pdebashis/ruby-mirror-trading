class StrategyMirror
  def initialize copy_accounts, feeder, logger=nil
	  @feeder = feeder
	  @users = copy_accounts
    Frappuccino::Stream.new(feeder).
    select{ |event| event.has_key?(:dict) && !event[:dict].nil? }.
    on_value(&method(:on_data))

    @logger = logger
    @report_name = Dir.pwd+"/reports/trades.csv"
    reporting "IDENTIFIER,USER,STATUS,MESSAGE,ORDER_ID,EXCHANGE,TIME,SYMBOL,INSTRUMENT,TYPE,TRANSACTION,VALIDITY,PRODUCT,QUANTITY,PRICE,TRIGGER-PRICE"
    url = "https://margincalculator.angelbroking.com/OpenAPI_File/files/OpenAPIScripMaster.json"
    resp = Net::HTTP.get_response(URI.parse(url))
    @all_data = JSON.parse(resp.body)
    @symbol_lot_size = 25
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
    msg = data[:message]
    exchange = data[:exchange]
    time = data[:o_time]
    symbol = data[:t_symbol]
    instrument = data[:t_instrument]
    type = data[:order_type]
    t_type = data[:t_type]
    validity = data[:validity]
    product = data[:product]
    quantity = data[:quantity]
    price = data[:price]
    trigger_price = data[:trigger_price]

    find_symbol = @all_data.filter { |x| x["symbol"].match?(symbol) && x["lotsize"] != "-1"}.first
    @symbol_lot_size = find_symbol["lotsize"].to_i unless find_symbol.nil?
    @x_times = quantity/@symbol_lot_size

    @logger.info "Master #{t_type} #{@x_times}x lotsize (#{@symbol_lot_size})"

    reporting "MASTER,#{acc},#{status},#{msg},#{o_id},#{exchange},#{time},#{symbol},#{instrument},#{type},#{t_type},#{validity},#{product},#{quantity},#{price},#{trigger_price}"

    if status == "OPEN" and validity == "DAY" and algo_switch == "ON" and type == "MARKET"
      place_order symbol,t_type,dyn_master_switch,type,product
    end

    if status == "OPEN" and validity == "DAY" and algo_switch == "ON" and type == "LIMIT"
      modify_order symbol,t_type,dyn_master_switch,type,product,price,trigger_price,o_id
    end

    if status == "CANCELLED" and validity == "DAY" and algo_switch == "ON" and type == "LIMIT"
      modify_order symbol,t_type,dyn_master_switch,type,product,price,trigger_price,o_id
    end

    # if status == "UPDATE" and validity == "DAY" and algo_switch == "ON" and type == "LIMIT"
    #   modify_order symbol,t_type,dyn_master_switch,type,product,price,trigger_price,o_id
    # end

  end

  def reporting msg
    date_format = Time.now.getlocal("+05:30").strftime("%Y-%m-%d %H:%M:%S")
    File.open(@report_name,"a+") do |op|
      op << "#{date_format},#{msg}\n"
    end
  end

  def place_order symbol,t_type,dyn_master_switch,o_type,p_type
    @logger.info "Placing Order #{t_type} #{symbol}"
    refresh_users

    @users.each do |usr|
      api_usr = usr[:api]
      lot_size = usr[:lot_size] * @symbol_lot_size
      lot_size = usr[:lot_size] * @x_times * @symbol_lot_size if dyn_master_switch == "ON"
      lot_size = lot_size * usr[:holding] if t_type == "SELL" and dyn_master_switch == "OFF"
      api_usr.place_custom_order(symbol,t_type, lot_size, 0, o_type,p_type,0)
      
      reporting "COPY,#{usr[:id]},INITIATED,,,,,#{symbol},,#{o_type},#{t_type},,#{p_type},#{lot_size},0,0"

      if t_type == "BUY"
        usr[:holding] += 1
      elsif t_type == "SELL"
        usr[:holding] = 0
      end
    end

  end

  def modify_order symbol,t_type,dyn_master_switch,o_type,p_type,price,t_price,o_id
    @logger.info "Placing Order LIMIT #{t_type} #{symbol}"
    refresh_users

    @users.each do |usr|
      api_usr = usr[:api]
      lot_size = usr[:lot_size] * @symbol_lot_size
      lot_size = usr[:lot_size] * @x_times * @symbol_lot_size if dyn_master_switch == "ON"
      lot_size = lot_size * usr[:holding] if t_type == "SELL" and dyn_master_switch == "OFF"
      resp = api_usr.place_custom_order(symbol,t_type, lot_size, price, o_type,p_type,t_price)
      usr[o_id] = resp["data"]["orderid"] unless resp["data"].nil?
      reporting "COPY,#{usr[:id]},INITIATED,,#{usr[o_id]},,,#{symbol},,#{o_type},#{t_type},,#{p_type},#{lot_size},#{price},#{t_price}"

      if t_type == "BUY"
        usr[:holding] += 1
      elsif t_type == "SELL"
        usr[:holding] = 0
      end
    end

  end

  def refresh_users
    new_values = {}
    
    workbook = RubyXL::Parser.parse "#{Dir.pwd}/config/MirrorTradesystem.xlsx"
    workbook[0].each_with_index do |row,index|
      unless row.nil? or row[0].nil? or row[0].value.nil? or index <=2
        client = row[0].value
        lot_size = row[7].value
        new_values[client] = lot_size
      end
    end

    @logger.info new_values

    @users.each do |usr|
      unless new_values[usr[:client]].nil?
        usr[:lot_size] = new_values[usr[:client]]
      end
    end
  end
end
