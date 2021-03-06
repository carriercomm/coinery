module Api
  class ProductsController < ApplicationController
    before_filter :permission, only: [:create, :destroy, :update]
    
    # def_param_group :product do 
    #   param :title, String, :required => false
    #   param :description, String, :required => false
    #   # param :price, String
    #   # asset
    # end
    api :GET, '/products/:id/buy'
    def buy
      @product = Product.find(params[:id])
      render json: @product.as_json(:include => :assets, :methods => [:user, :btc])

    end

    api :POST, '/products/:id/purchase'
    def purchase
      # create customer
      @customer = Customer.new(email: params[:email])
      @customer.save
      # create transaction
      @product = Product.find(params[:id])
      @customer.transactions.new(product_id: @product.id, customer_id: @customer.id, usd: @product.price).save
      # send email
      Notifier.send_purchase_email(@product, @customer).deliver
      # add download links to to assets, no need to, I already have them
    end 
    
    
    api :GET, '/products/all', "Get all products"
    def all
      @products = Product.all
  
      render json: @products
    end

    api :GET, '/products/:id/assets', "Get assets of a product"
    def product_assets
      @product = Product.find(params[:id])
      @assets = @product.assets
  
      render json: @assets
    end

    api :GET, '/products/:id/customers', "Get all product's customers"
    def product_customers
      @product = current_user.products.find(params[:id])
      @customers = @products.customers
  
      render json: @customers
    end

    api :GET, '/products/:id/transactions', "Get all product's transactions(sales)"
    def product_transactions
      @product = current_user.products.find(params[:id])
      @transactions = @product.transactions
  
      render json: @transactions
    end

    
    api :GET, '/products', "Get all user's products"
    def user_all 
      @products = current_user.products
  
      render json: @products
    end
    
    api :GET, '/products/:id', "Show a individual product"
    def show
      @product = Product.find(params[:id])

      # janky (repeated)
      if @product.image.exists? 
       @product.image_url = @product.image.url(:large) #unless !@product.image.exists? 
      end

      render json: @product
    end
    
    api :POST, '/products', "Create a product"
    # param_group :product
    def create
      @product = current_user.products.new(product_params)

      if @product.save
        render json: @product, status: :created  #, location: @product
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end

    api :PUT, '/products/:id/publish', "Publish a product"
    # param_group :product
    def publish
      @product = current_user.products.find(params[:id])
      current_user.coinbase_auth.refresh #unless current_user.coinbase_auth.valid?

      @product.create_payment_code(coinbase_token)

      if @product.update(status: 2)
        head :no_content
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end
    
    api :PUT, '/products/:id', "Update a product"
    # param_group :product
    def update
      @product = current_user.products.find(params[:id])
      
      change_product = false

      # # check here if price changed, if it did, create new button code for coinbase iframe
      # # create new button code and update. 
      if ((@product.price.to_f != product_params[:price].to_f) && @product.status == 2) || (@product.button_code == nil && @product.status == 2)
        change_product = true
      end

      if @product.update(product_params)
        if @product.image.exists? 
          @product.image_url = @product.image.url(:large)
          @product.save
        end
        if change_product
          @product.create_payment_code(coinbase_token)
        end
        render json: product_params[:image]
        # head :no_content
      else
        render json: @product.errors, status: :unprocessable_entity
      end
    end
    
    api :DELETE, '/products/:id', "Delete a product"
    def destroy
      @product = current_user.products.find(params[:id])
      @product.destroy
  
      head :no_content
    end
  
    private
      def product_params
        params.permit(:title, :description, :price, :image, :status)
      end
  
  end
end

