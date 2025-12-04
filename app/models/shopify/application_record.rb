module Shopify
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    
    connects_to database: { 
      writing: :shopify, 
      reading: :shopify 
    }
  end
end

