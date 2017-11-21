class CreateNodes < ActiveRecord::Migration[5.1]
  def change
    create_table :nodes, comment: '見つかったノード' do |t|
      t.string :name, null: false, default: '', comment: 'ノード名'
      t.inet :ipaddr, null: false, default: '0.0.0.0', comment: 'IPアドレス'

      t.timestamps
    end
    add_column :devices, :node_id, :integer, foreign_key: true
    add_index :devices, [:node_id, :eoj], unique: true
  end
end
