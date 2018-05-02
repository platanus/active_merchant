require 'active_merchant/billing/gateways/ebanx_checkout/request.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module EbanxCheckout #:nodoc:
      class PurchaseRequest < Request
        def action
          'request'
        end
      end
    end
  end
end
