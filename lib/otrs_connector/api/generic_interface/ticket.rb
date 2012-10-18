module OTRSConnector
  module API
    module GenericInterface
      class Ticket
        include OTRSConnector::API::GenericInterface
        
        class << self
          # Create some extra instance class instance accessors for create/update methods
          attr_accessor :default_history_type, :default_history_comment
        end
        self.wsdl = OTRSConnector::API::GenericInterface.default_wsdl
        self.wsdl_endpoint = OTRSConnector::API::GenericInterface.default_wsdl_endpoint
        
        actions 'TicketGet', 'TicketCreate', 'TicketUpdate', 'TicketSearch'
        
        attribute :id, type: Integer
        attribute :age, type: Integer
        attribute :archive_flag
        attribute :change_by, type: Integer
        attribute :changed
        attribute :create_by, type: Integer
        attribute :create_unix_time, type: Integer
        attribute :created
        attribute :customer_id
        attribute :customer_user_id
        attribute :escalation_response_time, type: Integer
        attribute :escalation_solution_time, type: Integer
        attribute :group_id, type: Integer
        attribute :closed
        attribute :escalation_time, type: Integer
        attribute :escalation_update_time, type: Integer
        attribute :first_lock, type: Integer
        attribute :lock
        attribute :lock_id, type: Integer
        attribute :owner
        attribute :owner_id, type: Integer
        attribute :priority
        attribute :priority_id, type: Integer
        attribute :queue
        attribute :queue_id, type: Integer
        attribute :real_till_time_not_used, type: Integer
        attribute :responsible
        attribute :responsible_id, type: Integer
        attribute :slaid, type: Integer
        attribute :service_id, type: Integer
        attribute :service
        attribute :solution_in_min, type: Integer
        attribute :solution_time
        attribute :ticket_number, type: Integer
        attribute :title
        attribute :type
        attribute :type_id, type: Integer
        attribute :unlock_timeout, type: Integer
        attribute :until_time, type: Integer
        attribute :dynamic_fields
        attribute :articles
        attribute :state_id, type: Integer
        attribute :state
        attribute :customer_user
        
        def self.find(id, options={})
          new_options = {}
          options.each do |key,value|
            if value == true
              set_value = 1
            else
              set_value = 0
            end
          
            case key
            when :dynamic_fields
              new_options['DynamicFields'] = set_value
            when :extended
              new_options['Extended'] = set_value
            when :articles
              new_options['AllArticles'] = set_value
            when :attachments
              new_options['Attachments'] = set_value
            end
          end
          new_options['TicketID'] = id
          response = self.connect('TicketGet', new_options)[:ticket]
          response[:id] = response[:ticket_id]
          dynamic_fields = build_dynamic_fields_from_ticket_hash(response)
          ticket = new response.except(:article)
          ticket.articles = response[:article].collect do |a| 
            a[:id] = a[:article_id]
            Article.new a
          end
          ticket.dynamic_fields = dynamic_fields if dynamic_fields.any?
          ticket
        end
        
        # OTRS sends dynamic fields back as normal ticket fields, even though they should be separate
        # Fields come back as DynamicField_X where X is the field name
        # Here we split these out and create instances of the DynamicField class
        def self.build_dynamic_fields_from_ticket_hash(ticket)
          dynamic_fields = []
          ticket.each do |key, value|
            if key =~ /dynamic_field_/ and !value.nil?
              dynamic_fields << { name: key.to_s.gsub('dynamic_field_', ''), value: value }
            end
          end
          dynamic_fields.collect{|f| DynamicField.new f}
        end
        
        # Pass in an extra_options hash to supply your own history_type and history_comment
        def save(extra_options={})
          a = articles.first
          
          # Get just the dynamic_field attributes to send to OTRS
          new_dynamic_fields = dynamic_fields.collect{|f| {'Name' => f.name, 'Value' => f.value}} if dynamic_fields
          options = {
            'Ticket'          => {
              'Title'         => title,
              'QueueID'       => queue_id,
              'Queue'         => queue,
              'LockID'        => lock_id,
              'Lock'          => lock,
              'TypeID'        => type_id,
              'Type'          => type,
              'ServiceID'     => service_id,
              'Service'       => service,
              'SLAID'         => slaid,
              'StateID'       => state_id,
              'State'         => state,
              'PriorityID'    => priority_id,
              'Priority'      => priority,
              'OwnerID'       => owner_id,
              'Owner'         => owner,
              'ResponsibleID' => responsible_id,
              'Responsible'   => responsible,
              'CustomerUser'  => customer_user
            },
            'Article' => {
              'ArticleTypeID' => a.article_type_id,
              'ArticleType'   => a.article_type,
              'SenderType'    => a.sender_type,
              'MimeType'      => a.mime_type || 'text/plain',
              'Charset'       => a.charset || 'utf8',
              'From'          => a.from,
              'Subject'       => a.subject,
              'Body'          => a.body,
              'HistoryType'   => extra_options[:history_type] || self.class.default_history_type,
              'HistoryComment'  => extra_options[:history_comment] || self.class.default_history_comment
            },
            'DynamicField' => new_dynamic_fields
          }
          response = self.class.connect 'TicketCreate', options
          self.attributes = self.class.find(response[:ticket_id], dynamic_fields: true, articles: true).attributes
          self
        end
        
        
      end
    end
  end
end
require_relative 'ticket/article'
require_relative 'ticket/dynamic_field'