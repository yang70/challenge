require 'json'

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
  
  # This recusive method follows child relationships to the bottom of the tree,
  # and consolidates user and account data, grouping into the next highest
  # "subsidiary" type org, which will also be returned as a main Org in the results.
  # "Subsidiary" Orgs will maintain their relationships to the next parent "subsidiary"
  # or top-level Org, and all child relationships to next level "subsidiary" children
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
  
  # Calculates the support score based on it and all child Org account values
  def support_score
    result = @accounts
    
    @children.each do | child |
      result += child.accounts_with_subsidiaries
    end
    
    calculate_support_score( result )
  end
  
  # Recursive method which returns all account information including all child Orgs accounts
  # for all children down the tree from this point
  def accounts_with_subsidiaries
    result = @accounts
    
    @children.each do | child |
      result += child.accounts_with_subsidiaries
    end
    
    result
  end
  
  # Recursive method which returns all user information including all child Orgs users
  # for all children down the tree from this point
  def users_with_subsidiaries
    result = @users
    
    @children.each do | child |
      result += child.users_with_subsidiaries
    end
    
    result
  end
  
  private
  
  # Helper method to determine if given Org is a tree "root" or top-level
  def is_root?
    !@parent
  end
  
  # Given array of account objects, determines support score based on the requirements
  def calculate_support_score( accounts_array )
    total_revenue = accounts_array.reduce( 0 ) do | sum, acct |
      sum += acct[ "revenue" ]
    end
    
    ( total_revenue / 50000.0 ).ceil
  end
  
end