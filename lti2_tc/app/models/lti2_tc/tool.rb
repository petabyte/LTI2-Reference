module Lti2Tc
  class Tool < ActiveRecord::Base
    has_many :resources
    has_many :tool_settings, :as => :scopeable

    attr_accessible :product_name, :description, :is_enabled, :key, :secret, :created_at, :updated_at

    def get_tool_proxy
      (Lti2Commons::JsonWrapper.new self.tool_proxy)
    end
  end
end
