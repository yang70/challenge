require_relative 'api_operation'
require_relative 'org'

class DataIngestor
  
  def initialize( api_url, api_key )
    @api_url = api_url
    @api_key = api_key
  end
  
  def ingest_and_parse
    result = []
    orgs   = load_all( "/orgs" )
    
    orgs.each do | org |
      if org[ "type" ] == "sole"
        new_org = create_new_org( org[ "id" ], org[ "type" ] )
        result << new_org
      elsif org[ "parent_id" ].nil?
        new_org = create_new_org( org[ "id" ], org[ "type" ] )
        result << link_children( orgs, new_org )
      end
    end
    
    result
  end
  
  private
  
  def link_children( orgs, parent_org )
    children = orgs.select { | org | org[ "parent_id" ] == parent_org.id }
    
    children.each do | child_org |
      new_org = create_new_org( child_org[ "id" ], child_org[ "type" ], parent_org )
      parent_org.children << new_org
      link_children( orgs, new_org )
    end
    
    parent_org
  end
  
  def create_new_org( id, type, parent = nil )
    new_org = Org.new( id, type, parent )
    
    org_user_ids      = request.read( "/users/org/#{ id }" )
    new_org.users    += request.read_all_by_id( "/users", org_user_ids )
    new_org.accounts += accounts_hash[ id ]
    
    new_org
  end
  
  def load_all( path )
    resource_id_responses = request.read_all( path )
    resource_ids          = consolidate_ids( resource_id_responses )
    request.read_all_by_id( path, resource_ids )
  end
  
  def consolidate_ids( response_array )
    result = []
    response_array.each { | res | result += res[ "results" ] }
    result
  end

  def request
    @request ||= ApiOperation.new( @api_url, @api_key )
  end
  
  def parser
    @parser ||= DataParser.new
  end
  
  def accounts_hash
    @accounts_hash ||= begin
      result   = {}
      accounts = load_all( "/accounts" )
      
      accounts.each do | account | 
        org_id = account[ "org_id" ]
        
        if result[ org_id ]
          result[ org_id ] << account
        else
          result[ org_id ] = [ account ]
        end
      end
      
      result
    end
  end
  
end
