class ApplicationService
  def self.call(*args)
    new(*args).call
  end

  def initialize(*_)
    raise NotImplementedError
  end

  def call
    raise NotImplementedError
  end
end