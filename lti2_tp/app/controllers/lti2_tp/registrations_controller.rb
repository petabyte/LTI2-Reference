
module Lti2Tp
  class RegistrationsController < InheritedResources::Base
    protect_from_forgery :except => :create

    include Lti2Commons
    include MessageSupport
    include Signer

    def create
      # this signals initial POST from TC
      tool = params[:tool]
      if tool.present?
        tools = Tool.where(:id => tool)
        if tools.present?
          @tool = tools.first
        else
          tools = Tool.where(:tool_name => tool)
          if tools.present?
            @tool = tools.first
          end
        end
      end
      if @tool.nil?
        @tool = Tool.first
      end

      @registration = Lti2Tp::Registration.new
      @registration.user_id = params['user_id']
      @registration.tc_profile_url = params['tc_profile_url']
      @registration.reg_key = params['reg_key']
      @registration.reg_password = params['reg_password']
      @registration.launch_presentation_return_url = params['launch_presentation_return_url']
      @registration.message_type = "registration"
      @registration.status = "received"

      @tool_consumer_profile = @registration.get_tool_consumer_profile()
      tcp_wrapper = JsonWrapper.new @tool_consumer_profile

      @registration.tool_consumer_profile_json = @tool_consumer_profile.to_json
      @registration.tenant_name = tcp_wrapper.first_at('product_instance.service_owner.service_owner_name.default_value')
      @registration.tenant_id = nil
      @registration.tool_id = @tool.id
      @registration.tool_profile_json = @tool.get_tool_profile.to_json
      @registration.lti_version = @tool_consumer_profile['lti_version']

      @registration.save

      redirect_to "/lti_registration_wips?registration_id=#{@registration.id}&return_url=/lti2_tp/registrations"
    end

    def end_registration
      response = pre_process_tenant
      if response.nil?
        return
      else
        if response.kind_of?(Array)
          return unless response[0] == 200
        end
      end

      @registration = Lti2Tp::Registration.where(:tenant_key => @tenant.tenant_name).first

      json_str = request.body.read

      @registration = Registration.where(:tenant_id => params[:_tenant_id]).first
      end_registration_id = request.headers[Registration::END_REGISTRATION_ID_NAME]
      (abort_registration("Missing #{Registration::END_REGISTRATION_ID_NAME} header") and return) if end_registration_id.nil?
      (abort_registration("Out of sequence #{Registration::END_REGISTRATION_ID_NAME} header") \
        and return) if end_registration_id != @registration.end_registration_id

      begin
        tool_proxy_disposition_wrapper = JsonWrapper.new(json_str)
      rescue
        render :json => 'JSON validation failure', :status => '500'
      end

      tool_proxy_disposition = tool_proxy_disposition_wrapper.root
      tool_proxy_guid = tool_proxy_disposition['tool_proxy_guid']
      tool_proxy_id = tool_proxy_disposition['@id']
      disposition = tool_proxy_disposition['disposition']

      if disposition != 'commit'
        abort_registration("Tool Consumer requested abort") and return
      end

      @registration.tool_proxy_json = @registration.proposed_tool_proxy_json
      @registration.status = 'reregistered'
      @registration.proposed_tool_proxy_json = nil
      @registration.end_registration_id = nil

      # recover secret from new tool_proxy
      tool_proxy_wrapper = JsonWrapper.new(@registration.tool_proxy_json)
      @registration.reg_password = tool_proxy_wrapper.first_at('security_contract.shared_secret')
      @tenant.secret = @registration.reg_password
      @tenant.save

      @registration.save

      end_registration_response = {
          "@context" => "http://purl.imsglobal.org/ctx/lti/v2/ToolProxyId",
          "@type" => "ToolProxy",
          "@id" => tool_proxy_id,
          "tool_proxy_guid" => tool_proxy_guid,
          "disposition" => 'commit'
      }

      content_type = 'application/vnd.ims.lti.v2.toolproxy.id+json'
      logger.info("Exit from Tool/create(POST)--status 201  content-type: #{content_type}")
      logger.info(JSON.dump(end_registration_response))

      render :json => end_registration_response.to_json, :content_type => content_type, :status => '201'
    end

    def index
      registration = Lti2Tp::Registration.find(params[:id])
      final_hash = params.select {|k,v| [:status, :tool_guid, :lti_errormsg, :lti_errorlog].include? k.to_sym}
      final_qs = final_hash.to_query
      final_url = "#{registration.launch_presentation_return_url}?#{final_qs}"
      redirect_to final_url
    end

    def reregister
      response = pre_process_tenant
      if response.nil?
        return
      else
        if response.kind_of?(Array)
          return unless response[0] == 200
        end
      end

      @registration = Lti2Tp::Registration.where(:tenant_key => @tenant.tenant_name).first

      @registration.tc_profile_url = params['tc_profile_url']
      @registration.launch_presentation_return_url = params['launch_presentation_return_url']
      @registration.message_type = "reregistration"
      @registration.status = "received"

      # Use OLD key/secret to send NEW ToolProxy
      @registration.reg_key = @tenant.tenant_key
      @registration.reg_password = @tenant.secret
      @tool_consumer_profile = @registration.get_tool_consumer_profile()
      tcp_wrapper = JsonWrapper.new @tool_consumer_profile

      @registration.tool_consumer_profile_json = @tool_consumer_profile.to_json
      @registration.tenant_name = tcp_wrapper.first_at('product_instance.service_owner.service_owner_name.default_value')
      @registration.tenant_id = @tenant.id

      @tool = Tool.find(@registration.tool_id)
      @registration.tool_profile_json = @tool.get_tool_profile.to_json
      @registration.lti_version = @tool_consumer_profile['lti_version']

      @registration.save

      redirect_to "/lti_registration_wips?registration_id=#{@registration.id}&return_url=/lti2_tp/registrations"
    end

    def update
      get_tool_consumer_profile Lti2Tp::Context.get_holder(session)
      form_params = request.params['deployment_proposal']
      @registration = Lti2Tp::Registration.find(request.params[:id])
      @registration.tenant_name = form_params['tenant_name']

      is_tenant_exists = Tenant.where(:tenant_name=>@registration.tenant_name).exists?
      if @registration.message_type == "registration" and is_tenant_exists
        @registration.errors[:tenant_name] << "Institution name is already in database"
        return render_view
      elsif @registration.message_type == "reregistration" and not is_tenant_exists
        raise "Attempt to reregister but not tenant currently exists"
      end

      @tool_options = []
      params.each {|p|
        if p.first =~ /^tool_/
          @tool_options << p.first[5..-1]
        end
      }

      if @tool_options.length == 0
        @registration.errors[:tenant_name] << "You must check at least one tool below to download"
        return render_view
      end

      @registration.save!

      show
    end

    private

    def abort_registration(abort_msg)
      render :status => 500, :json => abort_msg
    end
  end
end