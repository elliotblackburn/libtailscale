defmodule TailscaleTest do
  use ExUnit.Case
  doctest Tailscale

  test "create a new tailscale instance" do
    # Note: This test will only pass if the NIF library is properly built and loaded
    # During development, you might want to mock the NIF calls
    {:ok, ts} = Tailscale.new()
    assert %Tailscale{} = ts
  end

  test "set configuration options" do
    # Since actual Tailscale operations require network connectivity
    # and potentially privileged operations, we'll just test the API interface here
    
    # This test makes assumptions about the implementation details
    # of how the configuration functions work - adjust as needed based on
    # your actual implementation
    {:ok, ts} = Tailscale.new()
    
    assert is_function(ts.reference)
    
    # Test all the configuration setters
    assert :ok = Tailscale.set_hostname(ts, "elixir-test")
    assert :ok = Tailscale.set_dir(ts, "/tmp/tailscale-test")
    assert :ok = Tailscale.set_ephemeral(ts, true)
    
    # Validate that we can successfully close the tailscale instance
    assert :ok = Tailscale.close(ts)
  end
end