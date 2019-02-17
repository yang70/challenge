class ApiOperationError < StandardError
  
  def initialize( error_message = nil )
    message = "Error: Invalid Response From API"
    
    message += " - Error Message: #{ error_message }" if error_message
    
    super( message )
  end
  
end
