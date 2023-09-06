require 'uri'
require 'digest'
require 'csv'
require 'rest-client'
require 'json'
require_relative 'payload.rb'

# Kite Connect API wrapper class.
# Initialize an instance for each Kite Connect user.
class PaisaConnect

  # Base URL
  # Can be overridden during initialization
  BASE_URL = "https://Openapi.5paisa.com/VendorsAPI/Service1.svc/"
  #LOGIN_ROUTE = f'{BaseUrl}V4/LoginRequestMobileNewbyEmail'
  LOGIN_URL = "#{BASE_URL}TOTPLogin" # Default Login URL
  TIMEOUT = 7 # In seconds
  API_VERSION = 3 # Use Kite API Version 3

  # URIs for API calls
  # Not all API calls are currently implemented
  ROUTES = {
    "api.request" => "TOTPLogin",
    "api.token" => "GetAccessToken",
    "api.token.invalidate" => "/session/token",
    "api.token.renew" => "/session/refresh_token",
    "user.profile" => "/user/profile",
    "user.margins" => "V4/Margin",

    "orders" => "/orders",
    "trades" => "/trades",

    "order.info" => "V2/OrderStatus",
    "order.place" => "V1/PlaceOrderRequest",
    "order.modify" => "V1/ModifyOrderRequest",
    "order.cancel" => "V1/CancelOrderRequest",
    
    "order.trades" => "/orders/%{order_id}/trades",
  }

  attr_accessor :api_key, :client_code, :access_token, :base_url, :timeout, :logger

  # Initialize a new KiteConnect instance
  # - api_key is application's API key
  # - access_token is the token obtained after complete login flow. Pre
  # login this will default to nil.
  # - base_url is the API endpoint root. If it's not specified, then
  # default BASE_URL will be used as root.
  # - logger is an instance of Rails Logger or any other logger used
  def initialize(api_key, client_code, logger = nil, access_token = nil, base_url = nil )
    self.api_key = api_key
    self.access_token = access_token
    self.client_code = client_code
    self.base_url = base_url || BASE_URL
    self.timeout = TIMEOUT
    self.logger = logger
  end

  # Remote login url to which a user needs to be redirected in order to
  # initiate login flow.
  def login_url
    return LOGIN_URL + "?v=#{API_VERSION}&api_key=#{api_key}"
  end

  # Setter method to set access_token
  def set_access_token(access_token)
    self.access_token = access_token
  end

  # Generate access_token by exchanging request_token
  def generate_access_token(userid, totp, mpin, secret )
    
    request_token_resp = post("api.request", {
      "Email_ID" => client_code.to_s,
      "TOTP" => totp.to_s.gsub('x','0'),
      "PIN" => mpin.to_s
    })

    request_token = request_token_resp["RequestToken"] if request_token_resp && request_token_resp["RequestToken"]

    resp = post("api.token", {
      "RequestToken" => request_token,
      "EncryKey" => secret,
      "UserId" => userid
    })

    puts resp
    # Set access token if it's present in response
    set_access_token(resp["AccessToken"]) if resp && resp["AccessToken"]

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
    get("user.profile")
  end

  # Get account balance and margins for specific segment (defaults to equity)
  def margins()
    resp = post("user.margins",{
      "ClientCode" => client_code.to_s
    })
    if resp.nil?
      false
    else
      resp["EquityMargin"].first
    end
  end

  # Get list of today's orders - completed, pending and cancelled
  def orders
    get("orders")
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
  # - exchange : NSE / BSE
  # - tradingsymbol is the symbol of the instrument
  # - transaction_type BUY / SELL
  # - quantity
  # - product MIS / CNC
  # - order_type MARKET / LIMIT / SL / SL-M
  # - price used in LIMIT orders
  # - trigger_price is the price at which an order should be triggered in case of SL / SL-M
  # - tag alphanumeric (max 8 chars) used to tag an order
  # - variety regular / bo / co / amo - defaults to regular
  #
  # Return order_id in case of success.
  def place_order(exchange, tradingsymbol, transaction_type, quantity, product,
                  order_type, price = nil, trigger_price = nil, tag = nil, variety = nil)
    params = {}
    params[:variety] = variety || "regular" # regular, bo, co, amo
    params[:exchange] = exchange || "NSE"
    params[:tradingsymbol] = tradingsymbol
    params[:transaction_type] = transaction_type
    params[:quantity] = quantity.to_i
    params[:product] = product
    params[:order_type] = order_type # MARKET, LIMIT, SL, SL-M
    params[:price] = price if price # For limit orders
    params[:trigger_price] = trigger_price if trigger_price
    params[:tag] = tag if tag

    resp = post("order.place", params)

    if resp && order_id = resp["order_id"]
      order_id
    else
      nil
    end
  end

  # Modify an order specified by order_id
  def modify_order(order_id, quantity = nil, order_type = nil, price = nil,
                   trigger_price = nil,symbol=nil,product=nil, validity = nil, disclosed_quantity = nil, variety = nil)
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
    resp = delete("order.cancel", {
      variety: "regular",
      order_id: order_id
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
    place_order("NFO", tradingsymbol, transaction_type, quantity, "NRML", order_type, price, trigger_price)
  end

  def place_custom_order(tradingsymbol, transaction_type, quantity, price, order_type, product_type, trigger_price = nil)
    place_order("NFO", tradingsymbol, transaction_type, quantity, product_type, order_type, price, trigger_price)
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
    c_payload = {}
    c_payload[:head] = if route == "api.token" or route == "api.request"
      {"Key" => api_key}
    else
      {"key" => api_key}
    end

    c_payload[:body] = params

    # Retrieve route from ROUTES hash
    uri = ROUTES[route] % params
    url = URI.join(base_url, uri)

    headers = HEADERS

    # Set auth_header if access_token is present
    if access_token
      headers['Cookie'] = COOKIE_CONST
      headers['Authorization'] = "bearer #{access_token}"
    end

    # RestClient requires query params to be set in headers :-/
    if ["get", "delete"].include?(method)
      headers[:params] = params
    end

    begin

    a = {:url => url.to_s,
    :headers => headers,
    :payload => ["post", "put"].include?(method) ? c_payload.to_json : nil}
    puts "============INPUT START===================="
    puts a
    puts "============INPUT END ======================"

      response = RestClient::Request.execute(
        url: url.to_s,
        method: method.to_sym,
        timeout: timeout,
        headers: headers,
        payload: ["post", "put"].include?(method) ? c_payload.to_json : nil
      )

    puts "============RESPONSE START===================="
    puts response
    puts "============RESPONSE END ======================"
    #logger.info response

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
      data = JSON.parse(response.body)["body"]
    when "text/csv"
      data = CSV.parse(response.body, headers: true)
    else
      data = JSON.parse(response.body)["body"]
    end

    return data
  end

end
