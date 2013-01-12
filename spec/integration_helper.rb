def live_and_cached(should, url, fixture, &block)
  it should, :live do
    block.call subject
  end

  it should, :cached do
    FakeWeb.register_uri :get, url,
      :response => File.read("spec/fixtures/" + fixture)
    block.call subject
  end
end
