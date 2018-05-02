require 'active_merchant/billing/gateways/ebanx_checkout/request.rb'
require 'active_merchant/billing/gateways/ebanx_checkout/purchase_request.rb'
require 'active_merchant/billing/gateways/ebanx_checkout/status_request.rb'
require 'active_merchant/billing/gateways/ebanx_checkout/response.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EbanxCheckoutGateway < Gateway
      self.test_url = 'https://sandbox.ebanx.com/ws'
      self.live_url = 'https://api.ebanx.com/ws'

      self.supported_countries = %w(BR)
      self.default_currency = 'USD'

      self.homepage_url = 'http://www.ebanx.com'
      self.display_name = 'Ebanx Checkout'

      PAYMENT_TYPE_CODE_MAPPING = {
        all: '_all',
        boleto: 'boleto',
        bank_transfer: '_tef',
        creditcard: '_creditcard'
      }

      def initialize(options = {})
        requires!(options, :integration_key)
        super
      end

      def setup_purchase(money, params = {})
        requires!(params, :order_id, :customer, :email, :country)

        post = {}
        add_invoice(post, money, params)
        add_customer(post, params)
        add_payment_method(post, params)
        add_gateway_config(post)

        request = EbanxCheckout::PurchaseRequest.new(post)
        response = parse(ssl_post(request.endpoint, request.data))
        build_response(response)
      end

      def details_for(params)
        requires!(params, :order_id, :hash)

        data = {
          merchant_payment_code: params[:order_id],
          hash: params[:hash]
        }

        add_gateway_config(data)

        request = EbanxCheckout::StatusRequest.new(data)
        response = parse(ssl_get(request.endpoint, {}))
        build_response(response)
      end

      def redirect_url_for(hash)
        "#{url.chomp('/ws')}/checkout?hash=#{hash}"
      end

      private

      def add_gateway_config(post)
        post[:integration_key] = options[:integration_key]
        post[:url] = url
      end

      def add_invoice(post, money, params)
        post[:amount] = amount(money)
        post[:currency_code] = (params[:currency] || currency(money))
        post[:merchant_payment_code] = params[:order_id]
      end

      def add_customer(post, params)
        post[:name] = params[:customer]
        post[:email] = params[:email]
        post[:country] = params[:country].to_s.downcase
      end

      def add_payment_method(post, params)
        return if params[:payment_type].blank?
        code = PAYMENT_TYPE_CODE_MAPPING[params[:payment_type].to_sym]
        raise ArgumentError.new("Invalid payment type: #{params[:payment_type]}") if code.blank?
        post[:payment_type_code] = code
      end

      def url
        test? ? test_url : live_url
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def build_response(raw_response)
        EbanxCheckout::Response.new(
          success_from(raw_response),
          message_from(raw_response),
          raw_response,
          test: test?,
          error_code: error_code_from(raw_response),
          authorization: authorization_from(raw_response)
        )
      end

      def success_from(response)
        response['status'] == 'SUCCESS'
      end

      def error_code_from(response)
        'processing_error' unless success_from(response)
      end

      def message_from(response)
        return 'Success' if success_from(response)
        response['status_message']
      end

      def authorization_from(response)
        response['payment']['hash'] if success_from(response)
      end
    end
  end
end
