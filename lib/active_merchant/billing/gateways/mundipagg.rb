module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MundipaggGateway < Gateway
      self.test_url = 'https://api.mundipagg.com/core/v1/'
      self.live_url = 'https://api.mundipagg.com/core/v1/'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.mundipagg.com/'
      self.display_name = 'Mundipagg'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_customer_data(post, options) unless payment.is_a?(String)
        add_shipping_address(post, options)
        add_payment(post, payment, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_customer_data(post, options) unless payment.is_a?(String)
        add_shipping_address(post, options)
        add_payment(post, payment, options)
        add_capture_flag(post, payment)
        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        post = {}
        post[:code] = authorization
        add_invoice(post, money, options)
        commit('capture', post, authorization)
      end

      def refund(money, authorization, options={})
        add_invoice(post={}, money, options)
        commit('refund', post, authorization)
      end

      def void(authorization, options={})
        commit('void', post=nil, authorization)
      end

      def store(payment, options={})
        post = {}
        options.update(name: payment.name)
        options = add_customer(post, options) unless options[:customer_id]
        add_payment(post, payment, options)
        commit('store', post, options[:customer_id])
      end

      def create_customer(options={})
        post = {}
        post[:name] = options[:name]
        commit('customer', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]')
          .gsub(%r(("cvv\\":\\")\d*), '\1[FILTERED]')
          .gsub(%r((card\\":{\\"number\\":\\")\d*), '\1[FILTERED]')
      end

      private

      def add_customer(post, options)
        customer = create_customer(options)
        options.update(customer_id: customer.authorization)
      end

      def add_customer_data(post, options)
        post[:customer] = {}
        post[:customer][:email] = options[:email]
      end

      def add_billing_address(post, options)
        billing = {}
        address = options[:billing_address] || options[:address]
        billing[:street] = address[:address1].match(/\D+/)[0].strip if address[:address1]
        billing[:number] = address[:address1].match(/\d+/)[0] if address[:address1]
        billing[:compliment] = address[:address2] if address[:address2]
        billing[:city] = address[:city] if address[:city]
        billing[:state] = address[:state] if address[:state]
        billing[:country] = address[:country] if address[:country]
        billing[:zip_code] = address[:zip] if address[:zip]
        billing[:neighborhood] = address[:neighborhood]
        billing
      end

      def add_shipping_address(post, options)
        if address = options[:shipping_address]
          post[:address] = {}
          post[:address][:street] = address[:address1].match(/\D+/)[0].strip if address[:address1]
          post[:address][:number] = address[:address1].match(/\d+/)[0] if address[:address1]
          post[:address][:compliment] = address[:address2] if address[:address2]
          post[:address][:city] = address[:city] if address[:city]
          post[:address][:state] = address[:state] if address[:state]
          post[:address][:country] = address[:country] if address[:country]
          post[:address][:zip_code] = address[:zip] if address[:zip]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = money
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_capture_flag(post, payment)
        if card_brand(payment) == 'voucher'
          post[:payment][:voucher][:capture] = false
        else
          post[:payment][:credit_card][:capture] = false
        end
      end

      def add_payment(post, payment, options)
        post[:customer][:name] = payment.name if post[:customer]
        post[:customer_id] = parse_auth(payment)[0] if payment.is_a?(String)
        post[:payment] = {}
        if payment.is_a?(String)
          add_credit_card(post, payment, options)
        elsif card_brand(payment) == 'voucher'
          add_voucher(post, payment, options)
        else
          add_credit_card(post, payment, options)
        end
      end

      def add_credit_card(post, payment, options)
        post[:payment][:payment_method] = "credit_card"
        post[:payment][:credit_card] = {}
        if payment.is_a?(String)
          post[:payment][:credit_card][:card_id] = parse_auth(payment)[1]
        else
          post[:payment][:credit_card][:card] = {}
          post[:payment][:credit_card][:card][:number] = payment.number
          post[:payment][:credit_card][:card][:holder_name] = payment.name
          post[:payment][:credit_card][:card][:exp_month] = payment.month
          post[:payment][:credit_card][:card][:exp_year] = payment.year
          post[:payment][:credit_card][:card][:cvv] = payment.verification_value
          post[:payment][:credit_card][:card][:billing_address] = add_billing_address(post, options)
        end
      end

      def add_voucher(post, payment, options)
        post[:payment][:payment_method] = "voucher"
        post[:payment][:voucher] = {}
        post[:payment][:voucher][:card] = {}
        post[:payment][:voucher][:card][:number] = payment.number
        post[:payment][:voucher][:card][:holder_name] = payment.name
        post[:payment][:voucher][:card][:holder_document] = options[:holder_document]
        post[:payment][:voucher][:card][:exp_month] = payment.month
        post[:payment][:voucher][:card][:exp_year] = payment.year
        post[:payment][:voucher][:card][:cvv] = payment.verification_value
        post[:payment][:voucher][:card][:billing_address] = add_billing_address(post, options)
      end
      
      def headers
        {
          'Authorization' => 'Basic ' + Base64.strict_encode64("#{@options[:api_key]}:"),
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def url_for(action, auth=nil)
        url = (test? ? test_url : live_url)
        return "#{url}customers/#{auth}/cards" if action == 'store'
        return "#{url}customers" if action == 'customer'
        url = "#{url}charges/"
        url =  "#{url}#{auth}/" if %w(refund void capture).include? action
        return  "#{url}capture/" if action == 'capture'
        return url
      end

      def commit(action, parameters, auth = nil)
        url = url_for(action, auth) 
        parameters.merge!(parameters[:payment][:credit_card].delete(:card)).delete(:payment) if action == 'store'
        if %w(refund void).include? action
          response = parse(ssl_request(:delete, url, post_data(parameters), headers))
        else
          response = parse(ssl_post(url, post_data(parameters), headers))
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, action),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
        rescue ResponseError => e
          message = get_error_message(e)
          case e.response.code
          when '400'
            return Response.new(false, "Invalid request; #{message}", {}, test: test?, error_code: Gateway::STANDARD_ERROR_CODE[:processing_error])
          when '401'
            return Response.new(false, "Invalid API key; #{message}", {}, test: test?, error_code: Gateway::STANDARD_ERROR_CODE[:config_error])
          when '404'
            return Response.new(false, "The requested resource does not exist; #{message}", {}, test: test?, error_code: Gateway::STANDARD_ERROR_CODE[:processing_error])
          when '412'
            return Response.new(false, "Valid parameters but request failed; #{message}", {}, test: test?, error_code: Gateway::STANDARD_ERROR_CODE[:processing_error])
          when '422'
            return Response.new(false, "Invalid parameters; #{message}", {}, test: test?, error_code: Gateway::STANDARD_ERROR_CODE[:processing_error])
          when '500'
            return Response.new(false, "An internal error occurred; #{message}", {}, test: test?, error_code: Gateway::STANDARD_ERROR_CODE[:processing_error])
          end
          raise

      end

      def success_from(response)
        %w[pending paid processing canceled active].include? response['status']
      end

      def get_error_message(error)
        JSON.parse(error.response.body)['message']
      end

      def message_from(response)
        return response['message'] if response['message']
        return response['last_transaction']['acquirer_message'] if response['last_transaction']
      end

      def authorization_from(response, action)
        return "#{response['customer']['id']}|#{response['id']}" if action == 'store'
        response['id']
      end

      def parse_auth(auth)
        auth.split('|')
      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE[:processing_error]
        end
      end
    end
  end
end
