module RailsAdmin
  module Config
    module Actions
      class Exception < ::Exception
      end
      class NoIdException < Exception
        def initialize event
          super I18n.t('admin.state_machine.no_id')
        end
      end
      class EventDisabledException < Exception
        def initialize event
          super I18n.t("admin.state_machine.event_disabled", event)
        end
      end
      class State < Base
        RailsAdmin::Config::Actions.register(self)

        # Is the action acting on the root level (Example: /admin/contact)
        register_instance_option :root? do
          false
        end

        register_instance_option :collection? do
          false
        end

        # Is the action on an object scope (Example: /admin/team/1/edit)
        register_instance_option :member? do
          true
        end

        register_instance_option :controller do
          Proc.new do |klass|
            unless @authorization_adapter.nil? || @authorization_adapter.authorized?(:all_events, @abstract_model, @object)
              @authorization_adapter.try(:authorize, params[:event].to_sym, @abstract_model, @object)
            end

            @state_machine_options = ::RailsAdminState::Configuration.new @abstract_model
            begin
              raise NoIdException.new unless params['id'].present?
              event = params[:event].to_sym
              raise EventDisabledException.new(@object.class.human_state_event_name(event)) if @state_machine_options.disabled?(event)
              if @object.send("fire_#{params[:attr]}_event".to_sym, params[:event].to_sym)
                @object.save!
                flash[:success] = I18n.t('admin.state_machine.event_fired', attr: params[:method], event: params[:event])
              else
                flash[:error] = @object.errors.full_messages.join(', ')
              end
            rescue Exception => e
              flash[:error] = e.to_s
            end
            redirect_to :back
          end
        end

        register_instance_option :http_methods do
          [:post]
        end
      end
    end
  end
end
