require 'active_merchant/billing/gateways/ebanx_checkout/request.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module EbanxCheckout #:nodoc:
      class StatusRequest < Request
        def action
          'query'
        end

        def endpoint
          [full_url, params.to_query].join('?')
        end
      end
    end
  end
end
