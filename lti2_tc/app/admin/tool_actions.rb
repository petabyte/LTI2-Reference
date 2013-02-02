
ActiveAdmin.register_page "Tool Actions" do
  menu :label => "Tool Actions", :parent => "LMS..."
  
    content :title => proc{ I18n.t("active_admin.dashboard") } do
    if params.has_key? "lti_errormsg"
      div :style => "color: red" do
        span params['lti_errormsg']
      end
    end

    method = params['method']
    tool_id = params['tool_id']
    
    if method == "toggle"
      tool = Tool.find(tool_id)
      toggle = params['toggle']
      if toggle
        tool.is_enabled = toggle == "true"
        tool.save
      end   
    elsif method == "reregister"
      deployment_request = DeploymentRequest.new   
      tool = Tool.find(tool_id)
      tool_consumer_registry = Rails.application.config.tool_consumer_registry
      tool_consumer_profile = ToolConsumerProfile.new
      tc_profile_str = tool_consumer_registry.tool_consumer_profile
      tc_deployment_url = tool_consumer_registry.tc_deployment_url
      html_body = ToolRegistration::reregister_tool current_admin_user, deployment_request, 
                      tool, tool_consumer_profile, tc_profile_str, tc_deployment_url,
                      "#{tc_deployment_url}/admin/tool_actions"
      render :inline => html_body
    end
    
    tools = Tool.order("product_name").all
    tools.each do |tool|
      if tool.is_enabled
        tool['toggle_label'] = 'YES [disable now]'
      else
        tool['toggle_label'] = 'NO [enable now]'
      end      
    end
    request['tools'] = tools
    
    render "tool_actions"

  end # content
end