module Librato
  module Rails
    module Subscribers

      # Controllers

      ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |*args|

        event = ActiveSupport::Notifications::Event.new(*args)
        controller = event.payload[:controller]
        action = event.payload[:action]

        format = event.payload[:format] || "all"
        format = "all" if format == "*/*"
        status = event.payload[:status]
        http_method = event.payload[:method]
        exception = event.payload[:exception]

        collector.group "rails.request" do |r|

          r.increment 'total'
          r.timing    'time', event.duration

          if exception
            r.increment 'exceptions'
          else
            r.timing 'time.db', event.payload[:db_runtime] || 0
            r.timing 'time.view', event.payload[:view_runtime] || 0
          end

          if http_method
            verb            = http_method.to_s.downcase
            controller_name = controller.to_s.downcase
            metric_name     = [controller_name, verb].join(".")
            r.group 'method' do |m|
              m.increment metric_name
              m.timing "#{metric_name}.time", event.duration
            end
          end

          unless status.blank?
            r.group 'status' do |s|
              s.increment status
              s.increment "#{status.to_s[0]}xx"
              s.timing "#{status}.time", event.duration
              s.timing "#{status.to_s[0]}xx.time", event.duration
            end
          end

          r.increment 'slow' if event.duration > 200.0
        end # end group

      end # end subscribe

    end
  end
end
