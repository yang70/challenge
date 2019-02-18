require 'json'

module Helpers
  
  def org_objects_to_json( org_objects_array )
    result = []
    
    org_objects_array.each do | org |
      result << {
        id: org.id,
        type: org.type,
        parent: ( org.parent ? org.parent.id : nil ),
        children: org.children.map(&:id),
        accounts: org.accounts,
        users: org.users,
        support_score: org.support_score
      }
    end
    
    JSON.pretty_generate( result )
  end
  
end