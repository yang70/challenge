require_relative 'api_operation'
require_relative 'org'

class DataIngestor
  
  def initialize( api_url, api_key )
    @api_url = api_url
    @api_key = api_key
  end
  
  # Ingests data from the API and returns Org objects with attributes and relationships
  def ingest_and_parse
    result = []
    
    orgs_hash.delete( :sole_orgs ).each do | solo_org |
      result << create_new_org( solo_org[ "id" ], solo_org[ "type" ] )
    end
    
    orgs_hash.delete( :top_level_orgs ).each do | top_level_org |
      new_org = create_new_org( top_level_org[ "id" ], top_level_org[ "type" ] )
      result << link_children( new_org )
    end
    
    result
  end
  
  private
  
  # Recursive method to create the Org relationships
  def link_children( parent_org )
    children = orgs_hash.delete( parent_org.id )
    
    if children
      children.each do | child_org |
        new_org = create_new_org( child_org[ "id" ], child_org[ "type" ], parent_org )
        parent_org.children << new_org
        link_children( new_org )
      end
    end
    
    parent_org
  end
  
  # Creates an Org object and populates its Users and Accounts attributes
  def create_new_org( id, type, parent = nil )
    new_org = Org.new( id, type, parent )
    
    org_user_ids      = request.read( "/users/org/#{ id }" )
    new_org.users    += request.read_all_by_id( "/users", org_user_ids )
    new_org.accounts += accounts_hash.delete( id )
    
    new_org
  end
  
  # Reads all available resources for the given path
  def load_all( path )
    resource_id_responses = request.read_all( path )
    resource_ids          = consolidate_ids( resource_id_responses )
    request.read_all_by_id( path, resource_ids )
  end
  
  # Concatenates API results ID arrays into one
  def consolidate_ids( response_array )
    result = []
    response_array.each { | res | result += res[ "results" ] }
    result
  end

  # Memoized reusable helper method to interface with API Operations
  def request
    @request ||= ApiOperation.new( @api_url, @api_key )
  end
  
  # Memoized method that loads all data from the orgs API endpoint into a hash.
  # It separates into "sole", "top level" and children grouped by parent ID.
  def orgs_hash
    @orgs_hash ||= begin
      result = {}
      orgs   = load_all( "/orgs" )
      
      orgs.each do | org |
        if org[ "type" ] == "sole"
          if result[ :sole_orgs ]
            result[ :sole_orgs ] << org
          else
            result[ :sole_orgs ] = [ org ]
          end
        elsif org[ "parent_id" ].nil?
          if result[ :top_level_orgs ]
            result[ :top_level_orgs ] << org
          else
            result[ :top_level_orgs ] = [ org ]
          end
        else
          if result[ org[ "parent_id" ] ]
            result[ org[ "parent_id" ] ] << org
          else
            result[ org[ "parent_id" ] ] = [ org ]
          end
        end
      end
      
      result
    end
  end
  
  # Memoized method that loads all data from the accounts API endpoint into a hash
  # It groups into accounts belonging to the same org, keyed by the org id
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
