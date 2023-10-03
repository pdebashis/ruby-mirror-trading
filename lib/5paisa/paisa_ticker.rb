require 'uri'
require 'digest'
require 'csv'
require 'rest-client'
require 'json'

class PaisaTicker
  ROOT_URI = "wss://openfeed.5paisa.com/Feeds/api/chat"

  attr_accessor :socket_url, :logger, :client_code

  def initialize(access_token, client_code, logger=nil)
    self.client_code = client_code
    self.socket_url = ROOT_URI + "?Value1=#{access_token}|#{client_code}"
    self.logger = logger
  end

  def make_sense(bin)
    puts "Inside Make Sense"
    logger.debug "Inside Make Sense #{bin.class.name}"
    case bin.class.name
      when "WebSocket::Frame::Incoming::Client"
        bin.data
      else
        logger.debug "Recieved other than WebSocket::Frame::Incoming::Client"
        logger.debug bin
        bin
    end
  end
end