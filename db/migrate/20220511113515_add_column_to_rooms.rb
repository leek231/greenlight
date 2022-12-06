class AddColumnToRooms < ActiveRecord::Migration[5.2]
  def change
    add_column :rooms, :external_id, :integer
  end
end
