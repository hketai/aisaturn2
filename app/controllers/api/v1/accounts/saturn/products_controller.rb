class Api::V1::Accounts::Saturn::ProductsController < Api::V1::Accounts::BaseController
  before_action :authenticate_and_authorize
  before_action :load_product, only: [:show, :update, :destroy]

  def index
    @products = Current.account.shopify_products
                       .order(created_at: :desc)
                       .page(params[:page] || 1)
                       .per(params[:per_page] || 25)

    # Source filtresi
    @products = @products.by_source(params[:source]) if params[:source].present?

    # Arama
    if params[:query].present?
      query = "%#{params[:query].downcase}%"
      @products = @products.where('LOWER(title) LIKE ? OR LOWER(description) LIKE ?', query, query)
    end

    render json: {
      products: @products.map { |p| product_json(p) },
      meta: pagination_meta(@products)
    }
  end

  def show
    render json: { product: product_json(@product) }
  end

  def create
    @product = Current.account.shopify_products.new(permitted_params)
    @product.source = Shopify::Product::SOURCES[:manual]

    if @product.save
      render json: { product: product_json(@product) }, status: :created
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    # Shopify'dan gelen ürünler düzenlenemez
    if @product.shopify?
      render json: { error: 'Shopify ürünleri düzenlenemez' }, status: :forbidden
      return
    end

    if @product.update(permitted_params)
      render json: { product: product_json(@product) }
    else
      render json: { errors: @product.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # Shopify'dan gelen ürünler silinemez (sadece sync ile silinir)
    if @product.shopify?
      render json: { error: 'Shopify ürünleri silinemez' }, status: :forbidden
      return
    end

    @product.destroy!
    head :ok
  end

  private

  def authenticate_and_authorize
    authorize :saturn_product, :manage?
  end

  def load_product
    @product = Current.account.shopify_products.find(params[:id])
  end

  def permitted_params
    params.require(:product).permit(
      :title,
      :description,
      :min_price,
      :max_price,
      :total_inventory,
      :vendor,
      :product_type,
      :handle,
      images: []
    )
  end

  def product_json(product)
    {
      id: product.id,
      title: product.title,
      description: product.description,
      min_price: product.min_price,
      max_price: product.max_price,
      total_inventory: product.total_inventory,
      vendor: product.vendor,
      product_type: product.product_type,
      handle: product.handle,
      images: product.images,
      source: product.source,
      external_id: product.external_id,
      created_at: product.created_at,
      updated_at: product.updated_at,
      editable: !product.shopify?
    }
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end

