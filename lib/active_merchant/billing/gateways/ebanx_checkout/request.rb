module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module EbanxCheckout #:nodoc:
      class Request
        attr_reader :url, :params

        def initialize(params = {})
          @url = params.delete(:url)
          @params = params
        end

        def action
          raise NotImplementedError
        end

        def data
          params.to_json
        end

        def endpoint
          full_url
        end

        private

        def full_url
          [url, action].join('/')
        end
      end
    end
  end
end
