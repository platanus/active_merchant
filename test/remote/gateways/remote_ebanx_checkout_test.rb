require 'test_helper'

class RemoteEbanxCheckoutTest < Test::Unit::TestCase
  def setup
    @config = fixtures(:ebanx_checkout)
    @gateway = EbanxCheckoutGateway.new(@config)
    @amount = 100000
    @order_id = SecureRandom.hex(10)
    @hash = SecureRandom.hex(10)
    @customer = "Leandro"
    @email = "leandro@platan.us"
    @country = "BR"
    @payment_type = "all"
    @currency = "BRL"

    @purchase_options = {
      customer: @customer,
      email: @email,
      country: @country,
      order_id: @order_id,
      payment_type: @payment_type,
      currency: @currency
    }

    @details_options = {
      order_id: @order_id,
      hash: @hash
    }
  end

  def test_successful_purchase_setup
    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_purchase_setup_success(response)
  end

  def test_successful_purchase_setup_with_missing_country
    @purchase_options[:country] = nil

    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_purchase_setup_success(response)
  end

  def test_successful_purchase_setup_with_missing_currency
    @purchase_options[:currency] = nil

    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_purchase_setup_success(response)
  end

  def test_failed_purchase_setup_with_missing_email
    @purchase_options[:email] = ''

    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_request_failure(response, 'Parameter is required: email')
  end

  def test_failed_purchase_setup_with_missing_customer
    @purchase_options[:customer] = ''

    response = @gateway.setup_purchase(@amount, @purchase_options)
    assert_request_failure(response, 'Parameter is required: name')
  end

  def test_failed_details_with_missing_params
    response = @gateway.details_for(@details_options)
    error = "Payment not found for merchant, hash: #{@hash}, merchant_payment_code: #{@order_id}"
    assert_request_failure(response, error)
  end

  private

  def assert_purchase_setup_success(response)
    assert response.success?
    assert response.test?
    assert_equal 'Success', response.message
    assert_nil response.error_code
    assert !response.authorization.blank?
  end

  def assert_request_failure(response, message)
    assert !response.success?
    assert response.test?
    assert_equal message, response.message
    assert_equal 'processing_error', response.error_code
  end
end
