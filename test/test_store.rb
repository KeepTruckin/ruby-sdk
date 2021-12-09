require 'minitest/autorun'

class TestStore < Minitest::Test
  def setup
    super
    WebMock.enable!
  end

  def teardown
    super
    WebMock.disable!
  end

  def test_store_sync
    config_spec_mock_response = {
      'dynamic_configs' => [
        {'name' => 'config_1'},
        {'name' => 'config_2'}
      ],
      'feature_gates' => [
        {'name' => 'gate_1'},
        {'name' => 'gate_2'},
      ],
      'has_updates' => true,
      'id_lists' => {
        'list_1' => true,
      }
    }
    id_list_response_1 = {
      'add_ids' => %w[1 2 3],
      'remove_ids' => [],
      'time' => 1,
    }
    id_list_response_2 = {
      'add_ids' => %w[4 5 6],
      'remove_ids' => %w[1 2],
      'time' => 2,
    }
    stub_request(:post, 'https://api.statsig.com/v1/download_config_specs')
      .to_return(status: 200, body: JSON.generate(config_spec_mock_response))
    stub_request(:post, 'https://api.statsig.com/v1/download_id_list').
      with(body: /list_1/).
      to_return(status: 200, body: JSON.generate(id_list_response_1)).times(1).then.
      to_return(status: 200, body: JSON.generate(id_list_response_2))
    stub_request(:post, 'https://api.statsig.com/v1/download_id_list').
      with(body: /list_2/).
      to_return(status: 200, body: JSON.generate(id_list_response_1)).times(1).then.
      to_return(status: 200, body: JSON.generate(id_list_response_2))

    net = Network.new('secret-abc', 'https://api.statsig.com/v1/', 1)
    store = SpecStore.new(net, nil, 1, 1)

    assert(!store.get_config('config_1').nil?)
    assert(!store.get_config('config_2').nil?)
    assert(!store.get_gate('gate_1').nil?)
    assert(!store.get_gate('gate_2').nil?)
    assert(store.get_id_list('list_1') == { :ids => {'1'=>true, '2'=>true,'3'=>true,}, :time => 1 })
    assert(store.get_id_list('list_2').nil?)

    config_spec_mock_response = {
      'dynamic_configs' => [
        {'name' => 'config_1'},
      ],
      'feature_gates' => [
        {'name' => 'gate_1'},
      ],
      'has_updates' => true,
      'id_lists' => {
        'list_1' => true,
        'list_2' => true,
      }
    }


    stub_request(:post, 'https://api.statsig.com/v1/download_config_specs')
      .to_return(status: 200, body: JSON.generate(config_spec_mock_response))

    sleep 4

    assert(!store.get_config('config_1').nil?)
    assert(store.get_config('config_2').nil?)
    assert(!store.get_gate('gate_1').nil?)
    assert(store.get_gate('gate_2').nil?)
    assert(store.get_id_list('list_1') == { :ids => {'3'=>true, '4'=>true,'5'=>true,'6'=>true}, :time => 2 })
    assert(store.get_id_list('list_2') == { :ids => {'3'=>true, '4'=>true,'5'=>true,'6'=>true}, :time => 2 })
  end

  def test_no_id_lists_sync
    config_spec_mock_response = {
      'dynamic_configs' => [
        {'name' => 'config_1'},
        {'name' => 'config_2'}
      ],
      'feature_gates' => [
        {'name' => 'gate_1'},
        {'name' => 'gate_2'},
      ],
      'has_updates' => true,
      'id_lists' => {}
    }
    stub_request(:post, 'https://api.statsig.com/v1/download_config_specs')
      .to_return(status: 200, body: JSON.generate(config_spec_mock_response))

    net = Network.new('secret-abc', 'https://api.statsig.com/v1/', 1)
    spy = Spy.on(net, :post_helper).and_call_through
    SpecStore.new(net, nil, 1, 1)
    sleep 3
    assert(spy.calls.size == 3) # only download_config_specs were called, 3 times
  end
end