class AddImageSearchApprovedToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :image_search_approved, :boolean, default: false, null: false
  end
end
