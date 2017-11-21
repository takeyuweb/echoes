class CreateDevices < ActiveRecord::Migration[5.1]
  def change
    create_table :devices, comment: '見つかったスマートデバイス' do |t|
      t.string :name, null: false, default: '', comment: 'デバイス名'
      t.inet :ipaddr, null: false, default: '0.0.0.0', comment: 'IPアドレス'
      t.string :eoj, null: false, default: '', index: {unique: true}, comment: 'ECHONETオブジェクト'

      t.timestamps
    end
  end
end
