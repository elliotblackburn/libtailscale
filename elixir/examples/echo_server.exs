#!/usr/bin/env elixir

# This script demonstrates using Tailscale with Elixir to create a simple echo server
# You'll need to provide an auth key to run this example

Mix.install([
  {:tailscale, path: "../"}
])

defmodule EchoServer do
  require Logger

  def start do
    # Parse command line args
    auth_key = System.get_env("TS_AUTHKEY") || 
      raise "Please set the TS_AUTHKEY environment variable"
    
    hostname = System.get_env("TS_HOSTNAME") || "elixir-echo-server"
    port = String.to_integer(System.get_env("PORT") || "8080")
    
    # Initialize Tailscale
    {:ok, ts} = Tailscale.new()
    
    # Configure the instance
    ts
    |> configure(hostname, auth_key)
    
    # Connect to Tailscale network (blocks until connected)
    Logger.info("Connecting to Tailscale network...")
    :ok = Tailscale.up(ts)
    
    # Get our Tailscale IP addresses
    {:ok, ips} = Tailscale.get_ips(ts)
    Logger.info("Connected to Tailscale with IPs: #{ips}")
    
    # Create a listener
    {:ok, listener} = Tailscale.listen(ts, "tcp", ":#{port}")
    Logger.info("Listening on port #{port}")
    
    # Accept and handle connections
    accept_loop(ts, listener)
  end
  
  defp configure(ts, hostname, auth_key) do
    Logger.info("Configuring Tailscale with hostname: #{hostname}")
    
    # Set up basic configuration
    :ok = Tailscale.set_hostname(ts, hostname)
    :ok = Tailscale.set_ephemeral(true)
    :ok = Tailscale.set_auth_key(ts, auth_key)
    
    # Use a temp directory for state
    tmp_dir = Path.join(System.tmp_dir(), "tailscale-elixir-#{:os.system_time}")
    File.mkdir_p!(tmp_dir)
    :ok = Tailscale.set_dir(ts, tmp_dir)
    
    ts
  end
  
  defp accept_loop(ts, listener) do
    Logger.info("Waiting for connections...")
    
    # Accept a new connection
    {:ok, socket} = Tailscale.Listener.accept(listener)
    
    # Get remote address
    {:ok, remote_addr} = Tailscale.Listener.get_remote_addr(listener, socket)
    Logger.info("Connection from #{remote_addr}")
    
    # Spawn a process to handle this connection
    spawn(fn -> handle_connection(socket, remote_addr) end)
    
    # Continue accepting connections
    accept_loop(ts, listener)
  end
  
  defp handle_connection(socket, remote_addr) do
    # Convert to Erlang socket module
    {:ok, socket_mod} = :gen_tcp.connect({:local, socket}, 0, [])
    
    # Echo loop
    echo_loop(socket_mod, remote_addr)
  end
  
  defp echo_loop(socket, remote_addr) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        Logger.info("Received #{byte_size(data)} bytes from #{remote_addr}")
        :ok = :gen_tcp.send(socket, data)
        echo_loop(socket, remote_addr)
      
      {:error, :closed} ->
        Logger.info("Connection closed by #{remote_addr}")
        :ok = :gen_tcp.close(socket)
      
      {:error, reason} ->
        Logger.error("Error handling connection from #{remote_addr}: #{inspect(reason)}")
        :ok = :gen_tcp.close(socket)
    end
  end
end

EchoServer.start()