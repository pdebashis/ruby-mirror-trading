require 'uri'
require 'digest'
require 'csv'
require 'rest-client'
require 'json'

class PaisaTicker
  EXCHANGE_MAP = {
        nse: 1,
        nfo: 2,
        cds: 3,
        bse: 4,
        bfo: 5,
        bsecds: 6,
        mcx: 7,
        mcxsx: 8,
        indices: 9
  }

  ROOT_URI = "wss://openfeed.5paisa.com/Feeds/api/chat"

  MODES = ["full","quote","ltp"]

  attr_accessor :socket_url, :logger, :client_code

  def initialize(access_token, client_code, logger=nil)
    self.client_code = client_code
    self.socket_url = ROOT_URI + "?Value1=#{access_token}|#{client_code}"
    self.logger = logger
  end

  def make_sense(bin)
    puts "Inside Make Sense #{bin.class.name}"
    case bin.class.name
      when "String"
        logger.debug "Non binary data received on socket"
      when "Array"
        logger.debug "Array data received on socket"
      when "WebSocket::Frame::Incoming::Client"
        bin
      else
        logger.debug bin
        bin
    end
  end
end