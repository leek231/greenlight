class AddColumnToUserTable < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :external_id, :integer
  end
end
