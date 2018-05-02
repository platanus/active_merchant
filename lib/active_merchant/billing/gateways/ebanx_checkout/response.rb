module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module EbanxCheckout #:nodoc:
      class Response < Response
        def hash
          payment['hash']
        end

        def pin
          payment['pin']
        end

        def country
          payment['country']
        end

        def order_id
          payment['merchant_payment_code']
        end

        def order_number
          payment['order_number']
        end

        def status
          payment['status']
        end

        def status_date
          payment['status_date']
        end

        def open_date
          payment['open_date']
        end

        def confirm_date
          payment['confirm_date']
        end

        def transfer_date
          payment['transfer_date']
        end

        def amount_br
          payment['amount_br']
        end

        def amount_ext
          payment['amount_ext']
        end

        def amount_iof
          payment['amount_iof']
        end

        def currency_rate
          payment['currency_rate']
        end

        def currency_ext
          payment['currency_ext']
        end

        def due_date
          payment['due_date']
        end

        def instalments
          payment['instalments']
        end

        def payment_type_code
          payment['payment_type_code']
        end

        def pre_approved
          payment['pre_approved']
        end

        def capture_available
          payment['capture_available']
        end

        def requested?
          status == 'OP'
        end

        def pending?
          status == 'PE'
        end

        def confirmed?
          status == 'CO'
        end

        def cancelled?
          status == 'CA'
        end

        private

        def payment
          @params['payment'] || {}
        end
      end
    end
  end
end
