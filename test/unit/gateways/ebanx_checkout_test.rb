require 'test_helper'

class EbanxCheckoutTest < Test::Unit::TestCase
  include CommStub

  def setup
    @url = EbanxCheckoutGateway.test_url
    @gateway = EbanxCheckoutGateway.new(integration_key: 'KEY')
    @amount = 100000
    @order_id = 10
    @customer = "Leandro"
    @email = "leandro@platan.us"
    @country = "BR"
    @payment_type = "all"
    @currency = "BRL"
    @hash = "5ae776cb6965f0d2fc1c3d549bf0df547e6ff783513f1daf"

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

  def test_urls
    assert_equal 'https://sandbox.ebanx.com/ws', EbanxCheckoutGateway.test_url
    assert_equal 'https://api.ebanx.com/ws', EbanxCheckoutGateway.live_url
  end

  def test_default_currency
    assert_equal 'USD', EbanxCheckoutGateway.default_currency
  end

  def test_supported_countries
    assert_equal %w(BR), EbanxCheckoutGateway.supported_countries
  end

  def test_homepage_url
    assert_equal 'http://www.ebanx.com', EbanxCheckoutGateway.homepage_url
  end

  def test_display_name
    assert_equal 'Ebanx Checkout', EbanxCheckoutGateway.display_name
  end

  def test_initialize_with_missing_key
    assert_raise_message("Missing required parameter: integration_key") do
      EbanxCheckoutGateway.new
    end
  end

  def test_successful_purchase_setup
    response = stub_comms do
      @gateway.setup_purchase(@amount, @purchase_options)
    end.check_request do |endpoint, data, _headers|
      expected_data = {
        'amount' => '1000.00',
        'country' => 'br',
        'currency_code' => 'BRL',
        'email' => 'leandro@platan.us',
        'integration_key' => 'KEY',
        'merchant_payment_code' => 10,
        'name' => 'Leandro',
        'payment_type_code' => '_all'
      }

      check_ebanx_post_request(endpoint, data, expected_data, 'request')
    end.respond_with(successful_purchase_setup_response)

    assert_request_success(response)
  end

  def test_successful_purchase_setup_with_payment_type
    @purchase_options[:payment_type] = :creditcard

    response = stub_comms do
      @gateway.setup_purchase(@amount, @purchase_options)
    end.check_request do |endpoint, data, _headers|
      expected_data = {
        'payment_type_code' => '_creditcard'
      }

      check_ebanx_post_request(endpoint, data, expected_data, 'request')
    end.respond_with(successful_purchase_setup_response)

    assert_request_success(response)
  end

  def test_successful_purchase_setup_with_different_currency
    @purchase_options[:currency] = "USD"

    response = stub_comms do
      @gateway.setup_purchase(@amount, @purchase_options)
    end.check_request do |endpoint, data, _headers|
      expected_data = {
        'currency_code' => 'USD'
      }

      check_ebanx_post_request(endpoint, data, expected_data, 'request')
    end.respond_with(successful_purchase_setup_response)

    assert_request_success(response)
  end

  def test_failed_purchase_setup_with_invalid_email
    @purchase_options[:email] = nil

    response = stub_comms do
      @gateway.setup_purchase(@amount, @purchase_options)
    end.check_request do |endpoint, data, _headers|
      expected_data = {
        'email' => nil
      }

      check_ebanx_post_request(endpoint, data, expected_data, 'request')
    end.respond_with(failed_response)

    assert_purchase_setup_failure(response)
  end

  def test_failed_purchase_setup_with_invalid_payment_type
    @purchase_options[:payment_type] = 'invalid'

    assert_raise_message("Invalid payment type: invalid") do
      @gateway.setup_purchase(@amount, @purchase_options)
    end
  end

  def test_failed_purchase_setup_with_missing_order_id
    @purchase_options.delete(:order_id)

    assert_raise_message("Missing required parameter: order_id") do
      @gateway.setup_purchase(@amount, @purchase_options)
    end
  end

  def test_redirect_url_for
    assert_equal("https://sandbox.ebanx.com/checkout?hash=#{@hash}", @gateway.redirect_url_for(@hash))
  end

  def test_successful_details
    response = stub_comms(@gateway, :ssl_get) do
      @gateway.details_for(@details_options)
    end.check_request do |endpoint, _headers|
      e = "#{@url}/query?hash=#{@hash}&integration_key=KEY&merchant_payment_code=#{@order_id}"
      assert_equal(e, endpoint)
    end.respond_with(successful_details_response)

    assert_details_success(response)
  end

  private

  def check_ebanx_post_request(endpoint, data, expected_data, action)
    assert_equal("#{@url}/#{action}", endpoint)

    if data && expected_data
      data = JSON.parse(data)
      expected_data.each do |k, v|
        assert_equal(data[k], v)
      end
    end
  end

  def assert_purchase_setup_failure(response)
    assert_failure(response)
    assert_nil(response.authorization)
    assert(response.test?)
  end

  def assert_details_success(response)
    assert_request_success(response)
    assert_equal(@hash, response.hash)
    assert_equal('272960161', response.pin)
    assert_equal('br', response.country)
    assert_equal(@order_id.to_s, response.order_id)
    assert_equal('order number', response.order_number)
    assert_equal('OP', response.status)
    assert_equal('status date', response.status_date)
    assert_equal('open date', response.open_date)
    assert_equal('confirm date', response.confirm_date)
    assert_equal('transfer date', response.transfer_date)
    assert_equal('3312.54', response.amount_br)
    assert_equal('1000.00', response.amount_ext)
    assert_equal('12.54', response.amount_iof)
    assert_equal('3.3000', response.currency_rate)
    assert_equal('USD', response.currency_ext)
    assert_equal('due date', response.due_date)
    assert_equal('1', response.instalments)
    assert_equal('_all', response.payment_type_code)
    assert_equal(false, response.pre_approved)
    assert_equal(false, response.capture_available)
  end

  def assert_request_success(response)
    assert_success(response)
    assert_equal(@hash, response.authorization)
    assert_equal('Success', response.message)
    assert(response.test?)
  end

  def successful_purchase_setup_response
    <<-RESPONSE
    {
      "payment": {
        "hash": "5ae776cb6965f0d2fc1c3d549bf0df547e6ff783513f1daf",
        "pin": "403692270",
        "country": "br",
        "merchant_payment_code": "10",
        "order_number": null,
        "status": "OP",
        "status_date": null,
        "open_date": "2018-04-30 20:04:26",
        "confirm_date": null,
        "transfer_date": null,
        "amount_br": "3312.54",
        "amount_ext": "1000.00",
        "amount_iof": "12.54",
        "currency_rate": "3.3000",
        "currency_ext": "USD",
        "due_date": "2018-05-03",
        "instalments": "1",
        "payment_type_code": "_all",
        "pre_approved": false,
        "capture_available": null
      },
      "redirect_url": "https://sandbox.ebanx.com/checkout/?hash=5ae776cb6965f0d2fc1c3d549bf0df547e6ff783513f1daf",
      "status": "SUCCESS"
    }
    RESPONSE
  end

  def successful_details_response
    <<-RESPONSE
    {
      "payment": {
        "hash": "5ae776cb6965f0d2fc1c3d549bf0df547e6ff783513f1daf",
        "pin": "272960161",
        "country": "br",
        "merchant_payment_code": "10",
        "order_number": "order number",
        "status": "OP",
        "status_date": "status date",
        "open_date": "open date",
        "confirm_date": "confirm date",
        "transfer_date": "transfer date",
        "amount_br": "3312.54",
        "amount_ext": "1000.00",
        "amount_iof": "12.54",
        "currency_rate": "3.3000",
        "currency_ext": "USD",
        "due_date": "due date",
        "instalments": "1",
        "payment_type_code": "_all",
        "pre_approved": false,
        "capture_available": false
      }
      ,"status": "SUCCESS"
    }
    RESPONSE
  end

  def failed_response
    <<-RESPONSE
    {
      "status": "ERROR",
      "status_code": "BP-R-5",
      "status_message": "error message"
    }
    RESPONSE
  end
end
