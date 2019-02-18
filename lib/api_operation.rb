require 'net/http'
require 'json'
require 'time'

require_relative 'api_operation_error'

class ApiOperation
  BASE_REQUEST_LIMIT_TIME = 0.5
  THROTTLE_SLEEP_TIME     = 4
  
  def initialize( base_url, api_key )
    @uri               = URI( base_url )
    @api_key           = api_key
    @last_request_time = nil
    @throttle          = false
  end
  
  def read( path, params = {} )
    req = form_request( path, params )
    res = make_request( req )
    JSON.parse( res.body )
  end
  
  def read_all( path, params = {} )
    results = []
    page    = 1
    pages   = 2
    
    until page > pages
      params[ :page ] = page
      page   += 1
      current = self.read( path, params )
      pages   = current[ "pages" ]
      results << current
    end
    
    results
  end
  
  def read_all_by_id( path, id_array, params = {} )
    results = []
    
    id_array.each do | id |
      results << self.read( path + "/#{ id }", params )
    end  
    
    results
  end
  
  private
  
  def form_request( path, params )
    @uri.path  = path
    @uri.query = nil
    @uri.query = URI.encode_www_form( params ) unless params.empty?
    
    req = Net::HTTP::Get.new( @uri )
    req[ 'x-api-key' ] = @api_key
    
    req
  end
  
  def make_request( req )
    response  = nil
    try_count = 1
    
    while try_count <= 5
      if @throttle
        sleep THROTTLE_SLEEP_TIME * try_count
      elsif @last_request_time
        while Time.now - @last_request_time < BASE_REQUEST_LIMIT_TIME
          sleep 0.1
        end
      end
      
      response = Net::HTTP.start( @uri.hostname, @uri.port ) do | http |
        http.request( req )
      end
      
      try_count += 1
      @last_request_time = Time.now
      
      code = response.code rescue nil
      
      case code
      when "200"
        @throttle = false
        break
      when "403"
        puts "Warning: API Rate Limit Reached - Throttling"
        puts "Request will be retried"
        @throttle = true
      else
        puts "Warning: API Gave Unexexpected or No Return"
        puts "Detail: #{ response.body }" if response
        puts "Request will be retried" unless try_count > 5
      end
    end
    
    validate_response( response )
  end
  
  def validate_response( response )
    return response if response and response.code == "200"
    
    error_message = response.body rescue nil
    raise ApiOperationError.new( error_message )
  end
end
