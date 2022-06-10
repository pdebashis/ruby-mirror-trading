require 'uri'
require 'digest'
require 'csv'
require 'rest-client'
require 'json'

# Kite Connect API wrapper class.
# Initialize an instance for each Kite Connect user.
class AngelConnect

  # Base URL
  # Can be overridden during initialization
  BASE_URL = "https://apiconnect.angelbroking.com"
  LOGIN_URL = "https://smartapi.angelbroking.com/publisher-login" # Default Login URL
  TIMEOUT = 10 # In seconds
  API_VERSION = 3 # Use Kite API Version 3
  BUY=1
  SELL=-1

  # URIs for API calls
  # Not all API calls are currently implemented
  ROUTES = {
    "api.token.invalidate" => "/session/token",
    "api.token.renew" => "/session/refresh_token",
    "user.margins" => "/api/v2/funds",
    "user.margins.segment" => "/user/margins/%{segment}",

    "orders" => "/orders",
    "trades" => "/trades",

    "order.info" => "/orders/%{order_id}",
    "order.place" => "/api/v2/orders",
    "order.modify" => "/orders/%{variety}/%{order_id}",
    "order.cancel" => "/orders/%{variety}/%{order_id}",
    "order.trades" => "/orders/%{order_id}/trades",

#angel broker
    "api.login" => "/rest/auth/angelbroking/user/v1/loginByPassword",
    "api.logout" => "/rest/secure/angelbroking/user/v1/logout",
    "api.token" => "/rest/auth/angelbroking/jwt/v1/generateTokens",
    "api.refresh" => "/rest/auth/angelbroking/jwt/v1/generateTokens",
    "user.profile" => "/rest/secure/angelbroking/user/v1/getProfile",

    "api.order.place" => "/rest/secure/angelbroking/order/v1/placeOrder",
    "api.order.modify" => "/rest/secure/angelbroking/order/v1/modifyOrder",
    "api.order.cancel" => "/rest/secure/angelbroking/order/v1/cancelOrder",
    "api.order.book" => "/rest/secure/angelbroking/order/v1/getOrderBook",
    
    "api.ltp.data" => "/rest/secure/angelbroking/order/v1/getLtpData",
    "api.trade.book" => "/rest/secure/angelbroking/order/v1/getTradeBook",
    "api.rms.limit" => "/rest/secure/angelbroking/user/v1/getRMS",
    "api.holding" => "/rest/secure/angelbroking/portfolio/v1/getHolding",
    "api.position" => "/rest/secure/angelbroking/order/v1/getPosition",
    "api.convert.position" => "/rest/secure/angelbroking/order/v1/convertPosition",

    "api.gtt.create" => "/gtt-service/rest/secure/angelbroking/gtt/v1/createRule",
    "api.gtt.modify" => "/gtt-service/rest/secure/angelbroking/gtt/v1/modifyRule",
    "api.gtt.cancel" => "/gtt-service/rest/secure/angelbroking/gtt/v1/cancelRule",
    "api.gtt.details" => "/rest/secure/angelbroking/gtt/v1/ruleDetails",
    "api.gtt.list" => "/rest/secure/angelbroking/gtt/v1/ruleList",

    "api.candle.data" => "/rest/secure/angelbroking/historical/v1/getCandleData"
  }

  attr_accessor :api_key, :api_secret, :access_token, :refresh_token, :base_url,:timeout, :logger, :data

  # Initialize a new KiteConnect instance
  # - api_key is application's API key
  # - access_token is the token obtained after complete login flow. Pre
  # login this will default to nil.
  # - base_url is the API endpoint root. If it's not specified, then
  # default BASE_URL will be used as root.
  # - logger is an instance of Rails Logger or any other logger used
  def initialize(api_key, logger = nil, base_url = nil, access_token = nil )
    self.api_key = api_key
    self.access_token = 
    self.refresh_token = 
    self.base_url = base_url || BASE_URL
    self.timeout = TIMEOUT
    self.logger = logger
    url = "https://margincalculator.angelbroking.com/OpenAPI_File/files/OpenAPIScripMaster.json"
    resp = Net::HTTP.get_response(URI.parse(url))
    self.data = JSON.parse(resp.body)

    self.logger.info "Angel Daily Data initialized with #{data.size}"
  end

  def get_angel_symbol_token zerodha_symbol

    symbol_name = zerodha_symbol.match(/([A-Z]+)/)[0]
    strike_price = zerodha_symbol[-7..-1]
    date_part = zerodha_symbol[symbol_name.length+2..-8]


    @logger.info "symbol_name = #{symbol_name}, strike_price = #{strike_price}, date_part = #{date_part}"
    
    if date_part.match?(/^[[:alpha:][:blank:]]+$/)
      all_monthly = self.data.filter { |x| x["symbol"].match?(symbol_name) && x["symbol"].match?(strike_price) && x["symbol"].match?(date_part) }
      all_monthly.sort_by{ |x| Time.strptime(x["expiry"],"%d%b%Y") }.last
    else
      date_part = "0#{date_part}" if date_part.size == 3
      date_final=Time.strptime(date_part,"%m%d").strftime("%d%b").upcase
      self.data.filter { |x| x["symbol"].match?(symbol_name) && x["symbol"].match?(strike_price) && x["symbol"].match?(date_final) }.first
    end
  end

  # Remote login url to which a user needs to be redirected in order to
  # initiate login flow.
  def login_url
    return LOGIN_URL + "?api_key=#{api_key}"
  end

  # Setter method to set access_token
  def set_access_token(access_token)
    self.access_token = access_token
  end

  def set_refresh_token(refresh_token)
    self.refresh_token = refresh_token
  end

  # Generate access_token by exchanging request_token
  def generate_access_token(client_id, api_secret)

    resp = post("api.login", {
      "clientcode" => client_id,
      "password" => api_secret
    })

    # Set access token if it's present in response
    if resp["status"] == true
      refresh_token = resp["data"]["refreshToken"]
      jwtToken = resp["data"]["jwtToken"]
      feedToken = resp["data"]["feedToken"]

      set_access_token(jwtToken)
      set_refresh_token(refresh_token)
    end

    return resp
  end

  # Invalidate access token on Kite and clear access_token from instance.
  # Call when a user logs out of application.
  def invalidate_access_token(access_token = nil)
    access_token = access_token || self.access_token

    resp = delete("api.token.invalidate", {
      "api_key" => api_key,
      "access_token" => access_token
    })

    set_access_token(nil) if resp

    return resp
  end

  # Get user's profile
  def profile
    get("api.rms.limit")
  end

  # Get account balance and margins for specific segment (defaults to equity)
  def margins(segment = "equity")
    if segment
      get("user.margins", {segment: segment})
    else
      get("user.margins")
    end
  end

  # Get list of today's orders - completed, pending and cancelled
  def orders
    get("orders")
  end

  # Get list of today's orders - completed, pending and cancelled
  def mf_orders
    get("mf.orders")
  end

  # Get history of individual order
  def order_history(order_id)
    get("order.info", {order_id: order_id})
  end

  # Tradebook
  # Get list of trades executed today
  def trades
    get("trades")
  end

  # Get list of trades executed for a particular order
  def order_trades(order_id)
    get("order.trades", {order_id: order_id})
  end

  # Get list of positions
  def positions
    get("portfolio.positions")
  end

  # Get list of holdings
  def holdings
    get("portfolio.holdings")
  end

  def instruments
    get("market.instruments.all")
  end

  def instruments_of_exchange(exchange_id)
    get("market.instruments", {exchange: exchange_id})
  end

  # Place an order
  # symbol       :"NSE:<instrument>",
  # qty          :25*lotsize,
  # type         :2         2->MARKET
  # side         :1         1->BUY,-1->SELL
  # productType  : CNC
  # limitPrice   : 0
  # stopPrice    : 0
  # validity     : DAY
  # disclosedQty : 0
  # offlineOrder : False
  # stopLoss     : 0
  # takeProfit   : 0 
  #
  # Return order_id in case of success.
  def place_order(exchange, tradingsymbol, transaction_type, quantity, product,
                  order_type, price = nil, trigger_price = nil, tag = nil, variety = nil)

    record = get_angel_symbol_token tradingsymbol

    @logger.info "Angel Daily Data Match = #{record}"

    params = {}
    exchange_type = exchange || "NSE"
    params[:exchange] = exchange_type
    params[:variety] = "NORMAL"
    params[:tradingsymbol] = record["symbol"]
    params[:symboltoken] = record["token"]
    params[:transactiontype] = transaction_type
    params[:ordertype] = order_type
    params[:producttype] = product
    params[:duration] = "DAY"
    params[:quantity] = quantity.to_i
    params[:price] = price
    params[:squareoff] = 0
    params[:stoploss] = 0

    logger.info "placing order"
    logger.info params

    resp = post("api.order.place", params)

    if resp && resp["data"] && order_id = resp["data"]["orderid"]
      order_id
    else
      nil
    end
  end

  # Modify an order specified by order_id
  def modify_order(order_id, quantity = nil, order_type = nil, price = nil,
                   trigger_price = nil, validity = nil, disclosed_quantity = nil, variety = nil)
    params = {}
    params[:variety] = variety || "regular" # regular, bo, co, amo
    params[:order_id] = order_id
    params[:quantity] = quantity.to_i if quantity
    params[:order_type] = order_type # MARKET, LIMIT, SL, SL-M
    params[:price] = price if price # For limit orders
    params[:trigger_price] = trigger_price if trigger_price
    params[:validity] = validity if validity
    params[:disclosed_quantity] = disclosed_quantity if disclosed_quantity

    resp = put("order.modify", params)

    if resp && order_id = resp["order_id"]
      order_id
    else
      nil
    end
  end

  # Cancel order specified by order_id
  def cancel_order(order_id)
    resp = delete("api.order.cancel", {
      variety: "NORMAL",
      orderid: order_id
    })

    if resp && order_id = resp["order_id"]
      order_id
    else
      nil
    end
  end

  # CNC => Cash N Carry
  # Wrapper around place_order to simplify placing a regular CNC order
  def place_cnc_order(tradingsymbol, transaction_type, quantity, price, order_type = "LIMIT", trigger_price = nil)
    place_order("NFO", tradingsymbol, transaction_type, quantity, "CARRYFORWARD", order_type, price, trigger_price)
  end

  def place_custom_order(tradingsymbol, transaction_type, quantity, price, order_type, product_type, trigger_price = nil)
    product_type_angel = product_type == "MIS" ? "INTRADAY" : "CARRYFORWARD"
    order_type_angel = case order_type
    when "MARKET" then "MARKET"
    when "LIMIT" then "LIMIT"
    when "SL" then "STOPLOSS_LIMIT"
    else 2
    end
    place_order("NFO", tradingsymbol, transaction_type, quantity, product_type_angel, order_type_angel, price, trigger_price)
  end

  # Wrapper around modify_order to simplify modifying a regular CNC order
  def modify_cnc_order(order_id, quantity, price, order_type = "LIMIT", trigger_price = nil)
    modify_order(order_id, quantity, order_type, price, trigger_price)
  end

  # Get list of all instruments available to trade in specified exchange
  # instrument_token, exchange_token, tradingsymbol, name, last_price, expiry, strike, tick_size, lot_size, instrument_type, segment, exchange
  def instruments(exchange = "NSE")
    get("market.instruments", {exchange: exchange})
  end

  # Get full quotes for specified instruments
  # instruments is a list of one or more instruments e.g NSE:INFY,NSE:TCS
  def quote(instruments)
    instruments = instruments.split(",") if instruments.is_a? String
    get("market.quote", RestClient::ParamsArray.new(instruments.collect{|i| [:i, i]}))
  end

  # GET OHLC for specified instruments
  def ohlc(instruments)
    instruments = instruments.split(",") if instruments.is_a? String
    get("market.quote.ohlc", RestClient::ParamsArray.new(instruments.collect{|i| [:i, i]}))
  end

  # Get last traded price for specified instruments
  def ltp(instruments)
    instruments = instruments.split(",") if instruments.is_a? String
    get("market.quote.ltp", RestClient::ParamsArray.new(instruments.collect{|i| [:i, i]}))
  end

  private

  # Alias for sending a GET request
  def get(route, params = nil)
    request(route, "get", params)
  end

  # Alias for sending a POST request
  def post(route, params = nil)
    request(route, "post", params)
  end

  # Alias for sending a PUT request
  def put(route, params = nil)
    request(route, "put", params)
  end

  # Alias for sending a DELETE request
  def delete(route, params = nil)
    request(route, "delete", params)
  end

  # Make an HTTPS request
  def request(route, method, params = nil)
    params = params || {}

    # Retrieve route from ROUTES hash
    uri = ROUTES[route] % params
    url = URI.join(base_url, uri)

    headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-UserType': 'USER',
      'X-SourceID': 'WEB',
      'X-ClientLocalIP': '127.0.0.1',
      'X-ClientPublicIP': '49.37.46.92',
      'X-MACAddress': '84-1B-77-FC-03-EB',
      'X-PrivateKey': api_key
    }

    if self.access_token
      auth_header = "Bearer #{self.access_token}"
      headers["Authorization"] = "#{auth_header}"
    end

    # RestClient requires query params to be set in headers :-/
    if ["get", "delete"].include?(method)
      headers[:params] = params
    end

    begin
      response = RestClient::Request.execute(
        url: url.to_s,
        method: method.to_sym,
        timeout: timeout,
        headers: headers,
        payload: ["post", "put"].include?(method) ? params.to_json : nil
      )

      logger.debug "Response: #{response.code} #{response}" if logger

    rescue RestClient::ExceptionWithResponse => err
      # Handle exceptions
      response = err.response

      # Log response in case of exception
      logger.debug "Response: #{response.code} #{response}" if logger

      case response["error_type"]
      when "TokenException"
        set_access_token(nil)
      when "UserException"
      when "OrderException"
      when "InputException"
      when "NetworkException"
      when "DataException"
      when "GeneralException"
      end
    end

    case response.headers[:content_type]
    when "application/json"
      data = JSON.parse(response.body)
    when "text/csv"
      data = CSV.parse(response.body, headers: true)
    end
    
    return data
  end

end
