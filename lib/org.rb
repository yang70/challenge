class Org
  attr_accessor :id, :type, :parent, :children, :accounts, :users
  
  def initialize( id, type, parent = nil )
    @id       = id
    @type     = type
    @parent   = parent
    @children = []
    @accounts = []
    @users    = []
  end
  
  def flatten( options = {} )
    res = {
      top: [],
      accounts: [],
      users: [],
      last_subs: []
    }
    
    if @type == "sole"
      res[ :top ] << self
    else
      @children.each do | child |
        children_result = child.flatten( options )
        
        res[ :top ]       += children_result[ :top ]
        res[ :accounts ]  += children_result[ :accounts ]
        res[ :users ]     += children_result[ :users ]
        res[ :last_subs ] += children_result[ :last_subs ]
      end
      
      @children = []
      
      if is_root? || @type == "subsidiary"
        @accounts += res[ :accounts ]
        @users    += res[ :users ]
        @children += res[ :last_subs ]
        
        @children.map { | child | child.parent = self }
        
        res[ :accounts ]  = []
        res[ :users ]     = []
        
        res[ :last_subs ] = [ self ]
        res[ :top ] << self
      else
        res[ :accounts ] += @accounts
        res[ :users ]    += @users
      end
    end
    
    is_root? ? res[ :top ] : res
  end
  
  def support_score
    result = @accounts
    
    @children.each do | child |
      result += child.accounts_with_subsidiaries
    end
    
    calculate_support_score( result )
  end
  
  def accounts_with_subsidiaries
    result = @accounts
    
    @children.each do | child |
      result += child.accounts_with_subsidiaries
    end
    
    result
  end
  
  def users_with_subsidiaries
    result = @users
    
    @children.each do | child |
      result += child.users_with_subsidiaries
    end
    
    result
  end
  
  def is_root?
    !@parent
  end
  
  private
  
  def calculate_support_score( accounts_array )
    total_revenue = accounts_array.reduce( 0 ) do | sum, acct |
      sum += acct[ "revenue" ]
    end
    
    ( total_revenue / 50000.0 ).ceil
  end
  
end