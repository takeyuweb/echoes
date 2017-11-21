class CreateDevices < ActiveRecord::Migration[5.1]
  def change
    create_table :devices, comment: '見つかったスマートデバイス' do |t|
      t.string :name, null: false, default: '', comment: 'デバイス名'
      t.string :eoj, null: false, default: '', comment: 'ECHONETオブジェクト'

      t.timestamps
    end
  end
end
