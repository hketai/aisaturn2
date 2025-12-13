module Ikas::IntegrationHelper
  IKAS_API_URL = 'https://api.ikas.com/api/v1/admin/graphql'.freeze
  IKAS_TOKEN_URL = 'https://api.ikas.com/api/v1/admin/oauth/token'.freeze
  IKAS_OAUTH_BASE_URL = 'https://api.ikas.com/api/v1/admin/oauth/authorize'.freeze

  # OAuth scopes for the application
  OAUTH_SCOPES = %w[
    read_customer
    read_order
    read_product
    read_stock
  ].freeze

  # Gets OAuth authorization URL
  #
  # @param store_name [String] The store subdomain (e.g., "mystore" for mystore.myikas.com)
  # @param state [String] The state parameter for CSRF protection
  # @return [String] The OAuth authorization URL
  def ikas_oauth_authorize_url(store_name, state)
    params = {
      client_id: ikas_client_id,
      redirect_uri: ikas_redirect_uri,
      response_type: 'code',
      scope: OAUTH_SCOPES.join(' '),
      state: state,
      store: store_name
    }

    "#{IKAS_OAUTH_BASE_URL}?#{URI.encode_www_form(params)}"
  end

  # Exchanges authorization code for access token
  #
  # @param code [String] The authorization code
  # @return [Hash, nil] Token response with access_token, refresh_token, expires_in
  def exchange_ikas_code_for_token(code)
    return nil if code.blank?

    uri = URI(IKAS_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = URI.encode_www_form(
      grant_type: 'authorization_code',
      client_id: ikas_client_id,
      client_secret: ikas_client_secret,
      redirect_uri: ikas_redirect_uri,
      code: code
    )

    response = http.request(request)

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("[Ikas] Token exchange failed: #{response.code} - #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("[Ikas] Token exchange error: #{e.message}")
    nil
  end

  # Refreshes access token using refresh token
  #
  # @param refresh_token [String] The refresh token
  # @return [Hash, nil] Token response with access_token, refresh_token, expires_in
  def refresh_ikas_token(refresh_token)
    return nil if refresh_token.blank?

    uri = URI(IKAS_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = URI.encode_www_form(
      grant_type: 'refresh_token',
      client_id: ikas_client_id,
      client_secret: ikas_client_secret,
      refresh_token: refresh_token
    )

    response = http.request(request)

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("[Ikas] Token refresh failed: #{response.code} - #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("[Ikas] Token refresh error: #{e.message}")
    nil
  end

  # Makes a GraphQL API request to Ikas
  #
  # @param access_token [String] The access token
  # @param query [String] The GraphQL query
  # @param variables [Hash] The query variables
  # @return [Hash, nil] The API response
  def ikas_graphql_request(access_token, query, variables = {})
    return nil if access_token.blank? || query.blank?

    uri = URI(IKAS_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{access_token}"
    request.body = { query: query, variables: variables }.to_json

    response = http.request(request)

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("[Ikas] GraphQL request failed: #{response.code} - #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("[Ikas] GraphQL request error: #{e.message}")
    nil
  end

  # Test connection to Ikas API by fetching merchant info
  #
  # @param access_token [String] The access token
  # @return [Hash, nil] Merchant info if successful
  def test_ikas_connection(access_token)
    query = <<~GRAPHQL
      query {
        me {
          id
          email
        }
        listStorefront {
          data {
            id
            name
            defaultLocale
            domain {
              isSubdomain
              domain
            }
          }
        }
      }
    GRAPHQL

    response = ikas_graphql_request(access_token, query)
    return nil unless response && response['data']

    {
      'email' => response.dig('data', 'me', 'email'),
      'storefront' => response.dig('data', 'listStorefront', 'data')&.first
    }
  rescue StandardError => e
    Rails.logger.error("[Ikas] Connection test failed: #{e.message}")
    nil
  end

  # Generate a secure state token for OAuth
  def generate_ikas_state
    SecureRandom.hex(32)
  end

  private

  def ikas_client_id
    @ikas_client_id ||= GlobalConfigService.load('IKAS_CLIENT_ID', nil)
  end

  def ikas_client_secret
    @ikas_client_secret ||= GlobalConfigService.load('IKAS_CLIENT_SECRET', nil)
  end

  def ikas_redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/ikas/callback"
  end
end
