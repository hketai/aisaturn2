module Ikas
  class ApiService
    include Ikas::IntegrationHelper

    IKAS_API_URL = 'https://api.ikas.com/api/v1/admin/graphql'.freeze

    def initialize(hook)
      @hook = hook
      @access_token = hook.access_token
    end

    # Fetches total product count
    def fetch_product_count(updated_since: nil)
      query = <<~GRAPHQL
        query ListProducts($pagination: PaginationInput, $updatedAtRange: DateRangeInput) {
          listProduct(pagination: $pagination, updatedAtRange: $updatedAtRange) {
            count
          }
        }
      GRAPHQL

      variables = {
        pagination: { page: 1, limit: 1 }
      }

      if updated_since.present?
        variables[:updatedAtRange] = {
          gte: updated_since.is_a?(String) ? updated_since : updated_since.iso8601
        }
      end

      response = make_request(query, variables)
      response&.dig('data', 'listProduct', 'count') || 0
    end

    # Fetches products with pagination
    def fetch_products(cursor: nil, limit: 50, updated_since: nil)
      query = <<~GRAPHQL
        query ListProducts($pagination: PaginationInput, $updatedAtRange: DateRangeInput) {
          listProduct(pagination: $pagination, updatedAtRange: $updatedAtRange) {
            count
            data {
              id
              name
              shortDescription
              description
              productVariantTypes {
                variantTypeId
                variantTypeName
                order
                variantValues {
                  variantValueId
                  variantValueName
                  order
                }
              }
              productType
              vendor
              tags
              brand {
                id
                name
              }
              categories {
                id
                name
              }
              variants {
                id
                sku
                barcodeList
                isActive
                prices {
                  sellPrice
                  discountPrice
                  currency
                }
                images {
                  imageId
                  order
                  isMain
                  isVideo
                }
                selectedVariantValues {
                  variantTypeId
                  variantTypeName
                  variantValueId
                  variantValueName
                }
                stock {
                  stockCount
                  stockLocationId
                }
              }
              createdAt
              updatedAt
            }
          }
        }
      GRAPHQL

      # Ikas uses page-based pagination, not cursor
      page = cursor.present? ? cursor.to_i : 1

      variables = {
        pagination: { page: page, limit: limit }
      }

      if updated_since.present?
        variables[:updatedAtRange] = {
          gte: updated_since.is_a?(String) ? updated_since : updated_since.iso8601
        }
      end

      response = make_request(query, variables)
      return { products: [], next_cursor: nil, has_next_page: false } unless response

      products_data = response.dig('data', 'listProduct', 'data') || []
      total_count = response.dig('data', 'listProduct', 'count') || 0

      products = products_data.map { |p| transform_product(p) }
      has_next_page = (page * limit) < total_count
      next_cursor = has_next_page ? (page + 1).to_s : nil

      {
        products: products,
        next_cursor: next_cursor,
        has_next_page: has_next_page
      }
    end

    # Fetches orders for a customer
    def fetch_orders_for_customer(email: nil, phone: nil, limit: 10)
      return [] if email.blank? && phone.blank?

      query = <<~GRAPHQL
        query ListOrder($email: String, $phone: String, $pagination: PaginationInput) {
          listOrder(customerEmail: $email, customerPhone: $phone, pagination: $pagination) {
            data {
              id
              orderNumber
              orderLineItemStatus
              currencyCode
              totalFinalPrice
              createdAt
              customer {
                id
                email
                phone
                firstName
                lastName
              }
              shippingAddress {
                firstName
                lastName
                city
                district
              }
              orderLineItems {
                id
                productName
                variantName
                quantity
                unitFinalPrice
              }
            }
          }
        }
      GRAPHQL

      variables = {
        pagination: { page: 1, limit: limit }
      }
      variables[:email] = email if email.present?
      variables[:phone] = phone if phone.present?

      response = make_request(query, variables)
      return [] unless response

      orders_data = response.dig('data', 'listOrder', 'data') || []
      orders_data.map { |o| transform_order(o) }
    end

    private

    def make_request(query, variables = {})
      ensure_valid_token!

      uri = URI(IKAS_API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@access_token}"
      request.body = { query: query, variables: variables }.to_json

      response = http.request(request)

      if response.code.to_i == 200
        parsed = JSON.parse(response.body)
        if parsed['errors'].present?
          Rails.logger.error "[Ikas API] GraphQL errors: #{parsed['errors']}"
        end
        parsed
      else
        Rails.logger.error "[Ikas API] Request failed: #{response.code} - #{response.body}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[Ikas API] Request error: #{e.message}"
      nil
    end

    def ensure_valid_token!
      settings = @hook.settings || {}
      token_expires_at = settings['token_expires_at']

      # Check if token is about to expire (within 5 minutes)
      if token_expires_at.present?
        expires_at = Time.parse(token_expires_at.to_s) rescue nil
        if expires_at && expires_at > 5.minutes.from_now
          return # Token is still valid
        end
      end

      # Try to refresh token
      refresh_token = settings['refresh_token']
      if refresh_token.present?
        token_response = refresh_ikas_token(refresh_token)
        if token_response && token_response['access_token']
          @hook.access_token = token_response['access_token']
          @access_token = token_response['access_token']
          @hook.settings['refresh_token'] = token_response['refresh_token'] if token_response['refresh_token']
          @hook.settings['token_expires_at'] = Time.current + token_response['expires_in'].to_i.seconds if token_response['expires_in']
          @hook.save!
        end
      end
    end

    def transform_product(product)
      variants = (product['variants'] || []).map do |v|
        prices = v['prices']&.first || {}
        stock_info = v['stock']&.first || {}

        variant_title = (v['selectedVariantValues'] || []).map { |sv| sv['variantValueName'] }.join(' / ')

        {
          'id' => v['id'],
          'title' => variant_title.presence || 'Default',
          'sku' => v['sku'],
          'barcode' => v['barcodeList']&.first,
          'price' => prices['discountPrice'] || prices['sellPrice'],
          'compare_at_price' => prices['sellPrice'],
          'inventory_quantity' => stock_info['stockCount'] || 0,
          'is_active' => v['isActive']
        }
      end

      # Calculate prices
      prices = variants.map { |v| v['price'].to_f }.compact
      min_price = prices.min || 0
      max_price = prices.max || 0

      # Calculate inventory
      total_inventory = variants.sum { |v| v['inventory_quantity'].to_i }

      # Get images from first variant with images
      images = []
      product['variants']&.each do |v|
        next if v['images'].blank?

        v['images'].each do |img|
          # Ikas returns imageId, we need to construct URL
          # Format: https://cdn.myikas.com/images/{merchantId}/{imageId}
          images << {
            'id' => img['imageId'],
            'src' => "https://cdn.myikas.com/images/#{img['imageId']}",
            'position' => img['order'],
            'is_main' => img['isMain']
          }
        end
        break if images.any?
      end

      {
        id: product['id'],
        title: product['name'],
        description: product['description'] || product['shortDescription'],
        handle: product['id'], # Ikas doesn't have handles like Shopify
        vendor: product['vendor'] || product.dig('brand', 'name'),
        product_type: product['productType'] || product.dig('categories', 0, 'name'),
        min_price: min_price,
        max_price: max_price,
        total_inventory: total_inventory,
        variants: variants,
        images: images,
        tags: product['tags']
      }
    end

    def transform_order(order)
      {
        id: order['id'],
        order_number: order['orderNumber'],
        status: order['orderLineItemStatus'],
        currency: order['currencyCode'],
        total_price: order['totalFinalPrice'],
        created_at: order['createdAt'],
        customer: order['customer'],
        shipping_address: order['shippingAddress'],
        line_items: (order['orderLineItems'] || []).map do |item|
          {
            id: item['id'],
            product_name: item['productName'],
            variant_name: item['variantName'],
            quantity: item['quantity'],
            price: item['unitFinalPrice']
          }
        end
      }
    end
  end
end

