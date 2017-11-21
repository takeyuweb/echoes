class Device < ApplicationRecord
  belongs_to :node, required: true
  validates :name, presence: true
  validates :eoj, presence: true

  def ipaddr
    node.ipaddr
  end
end
