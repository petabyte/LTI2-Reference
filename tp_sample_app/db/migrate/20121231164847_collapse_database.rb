class CollapseDatabase < ActiveRecord::Migration
  def change
  
    create_table "deployment_proposals", :force => true do |t|
      t.string   "tenant_name"
      t.string   "user_id"
      t.string   "reg_key"
      t.string   "reg_password"
      t.string   "tc_profile_url"
      t.string   "launch_presentation_return_url"
      t.string   "status"
      t.datetime "created_at",                     :null => false
      t.datetime "updated_at",                     :null => false
      t.string   "message_type"
    end
  
    create_table "iresources", :force => true do |t|
      t.integer  "tenant_id"
      t.string   "result_uri"
      t.string   "userid"
      t.string   "contextid"
      t.float    "score"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end
  
    create_table "registries", :force => true do |t|
      t.string   "name"
      t.text     "content"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end
  
    create_table "tenant_users", :force => true do |t|
      t.integer  "tenant_id"
      t.string   "user_id"
      t.string   "first_name"
      t.string   "last_name"
      t.string   "email"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end
  
    create_table "tenants", :force => true do |t|
      t.string   "tenant_key"
      t.string   "secret"
      t.string   "tenant_name"
      t.datetime "created_at",  :null => false
      t.datetime "updated_at",  :null => false
    end
  
    create_table "tool_deployments", :force => true do |t|
      t.integer  "tenant_id"
      t.integer  "tool_id"
      t.string   "product_name"
      t.text     "tool_proxy"
      t.datetime "created_at",   :null => false
      t.datetime "updated_at",   :null => false
      t.string   "key"
      t.string   "secret"
    end
  
    add_index "tool_deployments", ["key"], :name => "index_tool_deployments_on_key", :unique => true
  
    create_table "tools", :force => true do |t|
      t.string   "tool_name"
      t.text     "tool_profile_template"
      t.datetime "created_at",            :null => false
      t.datetime "updated_at",            :null => false
    end
    
  end
end
