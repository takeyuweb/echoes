class ApplicationService
  def self.call(*args)
    new.call(*args)
  end

  def call(*_)
    raise NotImplementedError
  end
end